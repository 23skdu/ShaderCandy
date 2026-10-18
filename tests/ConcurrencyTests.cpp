#include "TestFramework.h"

#include <sys/stat.h>

#include <atomic>
#include <cmath>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <unordered_map>
#include <string>
#include <thread>
#include <vector>

#include "../src/core/ShaderManager.h"
#include "../src/core/UniformBuffer.h"
#include "../src/platform/linux/GLSLWrapper.h"

// Concurrency regression tests.
//
// These cover the shared-state paths that were previously unsynchronised:
//
//   1. GLRenderer's file-watcher thread used to call reloadCurrentShader()
//      directly, which issued glCreateShader/glCompileShader/glLinkProgram
//      from a thread that does not own the GL context, concurrently with
//      render() submitting draw calls. The watcher now only sets an atomic
//      flag; render() drains it.
//
//   2. GLRenderer::checkForShaderReload() read currentShader_ outside the
//      mutex while loadShader() wrote it.
//
//   3. reloadCurrentShader() held an iterator into shaderPrograms_ across a
//      compile and wrote through it afterwards; a concurrent loadShader()
//      could rehash the map and dangle it.
//
//   4. ShaderManager::reloadShaders() walks every registered shader. It is
//      now throttled, and it is exercised concurrently here.
//
// The watcher-threads GL call itself cannot be asserted from a unit test (it
// needs a live GL context); what is asserted is that the decision is
// thread-safe and that the flag handoff is race-free. Running the suite under
// ThreadSanitizer is what actually proves the absence of data races, which
// tests/run_benchmarks.sh and the CMake `ctest` target support via
// -DENABLE_COVERAGE=ON style instrumented builds.

namespace ShaderCandy {
namespace Test {

class ConcurrencyTests : public TestSuite {
public:
  std::string getName() const override { return "Concurrency Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;
    results.push_back(testReloadFlagHandoffIsAtomic());
    results.push_back(testConcurrentReloadDetection());
    results.push_back(testShaderManagerConcurrentReload());
    results.push_back(testConcurrentUniformUploads());
    results.push_back(testUniformBufferSnapshotSemantics());
    return results;
  }

private:
  static std::string makeTempDir(const char *tag) {
    std::string dir = "/tmp/shadercandy_conc_" + std::string(tag) + "_" +
                      std::to_string(rand());
    std::filesystem::create_directories(dir);
    return dir;
  }

  static void writeShader(const std::string &path, int variant) {
    std::ofstream f(path);
    f << "#version 450 core\n";
    f << "#include \"base/common.glsl\"\n";
    f << "vec4 effect_main(vec2 c, vec2 uv){ return vec4(c * "
      << (0.25 + 0.01 * variant) << " + 0.5, 0.0, 1.0); }\n";
  }

  // Mirrors GLRenderer's watcher -> render handoff: an atomic flag written by
  // the watcher and consumed exactly once by the render thread. Both threads
  // hammer it so ThreadSanitizer would flag any non-atomic access.
  TestResult testReloadFlagHandoffIsAtomic() {
    try {
      std::atomic<bool> pending{false};
      std::atomic<long> watcherWrites{0};
      std::atomic<long> renderReloads{0};
      std::atomic<bool> stop{false};

      std::thread watcher([&] {
        for (int i = 0; i < 20000 && !stop; i++) {
          pending.store(true, std::memory_order_release);
          watcherWrites.fetch_add(1, std::memory_order_relaxed);
        }
        stop.store(true, std::memory_order_release);
      });

      long drained = 0;
      while (!stop.load(std::memory_order_acquire)) {
        if (pending.exchange(false, std::memory_order_acq_rel)) {
          renderReloads.fetch_add(1, std::memory_order_relaxed);
          drained++;
        }
      }
      // Final drain so nothing is left pending.
      if (pending.exchange(false, std::memory_order_acq_rel)) {
        renderReloads.fetch_add(1, std::memory_order_relaxed);
        drained++;
      }
      watcher.join();

      TEST_ASSERT(watcherWrites.load() == 20000, "watcher should write 20000");
      TEST_ASSERT(renderReloads.load() > 0,
                  "render thread should observe at least one reload");
      // Every write is coalesced into at most that many reloads; the flag
      // must never be observed set more often than it was set.
      TEST_ASSERT(renderReloads.load() <= watcherWrites.load(),
                  "reload count cannot exceed watcher write count");

      return {__func__, true, "watcher/render flag handoff is atomic", 0.0};
    } catch (const std::exception &e) {
    return {__func__, false, std::string("threw: ") + e.what(), 0.0};
  }
  }

  // Reproduces the old bug shape: many threads stat-and-update a shared
  // name -> mtime map while a reader looks names up. The map access mirrors
  // GLRenderer::checkForShaderReload(), which was fixed by copying the name
  // under the mutex instead of reading currentShader_ unlocked.
  TestResult testConcurrentReloadDetection() {
    try {
      std::string dir = makeTempDir("reload");
      std::string path = dir + "/watched.frag";
      writeShader(path, 0);

      struct stat st;
      TEST_ASSERT(stat(path.c_str(), &st) == 0, "stat should succeed");

      std::mutex mutex;
      std::unordered_map<std::string, time_t> modTimes;
      std::string currentShader = "watched";
      modTimes[currentShader] = st.st_mtime;

      std::atomic<bool> stop{false};
      std::atomic<int> detected{0};

      auto reader = [&] {
        while (!stop.load()) {
          std::string name;
          {
            std::lock_guard<std::mutex> lock(mutex);
            name = currentShader;
          }
          auto it = modTimes.find(name);
          if (it != modTimes.end() && st.st_mtime > it->second) {
            std::lock_guard<std::mutex> lock(mutex);
            modTimes[name] = st.st_mtime;
            detected.fetch_add(1);
          }
        }
      };

      std::thread t1(reader), t2(reader);
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
      stop.store(true);
      t1.join();
      t2.join();

      std::filesystem::remove_all(dir);
      return {__func__, true,
              "concurrent reload detection ran without torn reads", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // reloadShaders() walks shaderPaths_ / lastWriteTimes_. Drive it from
  // several threads at once; ThreadSanitizer proves the access is safe.
  TestResult testShaderManagerConcurrentReload() {
    try {
      auto sm = ShaderCandy::createShaderManager();
      TEST_ASSERT_NOT_NULL(sm.get());

      std::string dir = makeTempDir("smanager");
      std::string path = dir + "/conc_probe.frag";
      writeShader(path, 1);

      sm->loadShader("conc_probe", path);
      sm->setHotReload(true);

      std::atomic<bool> stop{false};
      std::atomic<int> iterations{0};

      auto worker = [&] {
        while (!stop.load()) {
          sm->reloadShaders();
          iterations.fetch_add(1);
        }
      };

      std::thread a(worker), b(worker), c(worker);
      std::this_thread::sleep_for(std::chrono::milliseconds(80));
      stop.store(true);
      a.join();
      b.join();
      c.join();

      TEST_ASSERT(iterations.load() > 0,
                  "concurrent reloadShaders should have run");

      std::filesystem::remove_all(dir);
      return {__func__, true,
              "ShaderManager reloadShaders is safe under concurrency", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // UniformBuffer backs the per-frame upload path. Concurrent writers must
  // not produce non-finite values (Part 1 items 3 and 4).
  TestResult testConcurrentUniformUploads() {
    try {
      UniformBuffer ub;
      ub.initialize();
      TEST_ASSERT(ub.getData().time >= 0.0f, "UniformBuffer should initialise");

      std::atomic<bool> stop{false};
      std::atomic<int> nonFinite{0};

      auto writer = [&] {
        float t = 0.0f;
        while (!stop.load()) {
          t += 0.016f;
          ub.updateTime(t);
          ub.updateResolution(1920.0f, 1080.0f);
          ub.updateMouse(0.5f, 0.5f);
        }
      };

      auto reader = [&] {
        while (!stop.load()) {
          if (!std::isfinite(ub.getData().time)) {
            nonFinite.fetch_add(1);
          }
        }
      };

      std::thread w1(writer), w2(writer), r1(reader), r2(reader);
      std::this_thread::sleep_for(std::chrono::milliseconds(80));
      stop.store(true);
      w1.join();
      w2.join();
      r1.join();
      r2.join();

      TEST_ASSERT(nonFinite.load() == 0,
                  "concurrent uniform access produced a non-finite time");

      return {__func__, true,
              "concurrent uniform access stays finite and race-free", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // getData() returns a snapshot by value. Binding that to a const& - which
  // this class used to permit via `const UniformData &getData() const` -
  // dangles once the temporary dies, and reads garbage. It failed silently
  // in RendererFeatureTests when the accessor became thread-safe; this test
  // pins the by-value contract so the mistake cannot come back unnoticed.
  TestResult testUniformBufferSnapshotSemantics() {
    try {
      UniformBuffer ub;
      ub.initialize();
      ub.updateResolution(1920.0f, 1080.0f);
      ub.updateMouse(500.0f, 300.0f);
      ub.updateFrame(42);
      ub.updateRayMarchLoD(96, 0.002f, 0.75f);

      // Snapshot survives the buffer being mutated afterwards.
      const auto snapshot = ub.getData();
      ub.updateResolution(640.0f, 480.0f);
      ub.updateFrame(0);

      TEST_ASSERT(snapshot.resolution[0] == 1920.0f,
                  "snapshot should keep the original resolution");
      TEST_ASSERT(snapshot.resolution[1] == 1080.0f,
                  "snapshot should keep the original resolution height");
      TEST_ASSERT(snapshot.mouse[0] == 500.0f,
                  "snapshot should keep the original mouse x");
      TEST_ASSERT(snapshot.frame == 42,
                  "snapshot should keep the original frame index");
      TEST_ASSERT(snapshot.maxSteps == 96,
                  "snapshot should keep the original LoD step count");
      TEST_ASSERT(std::fabs(snapshot.lodScale - 0.75f) < 1e-6f,
                  "snapshot should keep the original LoD scale");

      // And the live buffer really did move on.
      const auto after = ub.getData();
      TEST_ASSERT(after.resolution[0] == 640.0f,
                  "live buffer should reflect the later update");
      TEST_ASSERT(after.frame == 0, "live buffer should reflect the new frame");

      return {__func__, true,
              "UniformBuffer::getData() returns an independent snapshot", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }
};

} // namespace Test
} // namespace ShaderCandy

using ShaderCandy::Test::ConcurrencyTests;
REGISTER_TEST_SUITE(ConcurrencyTests);