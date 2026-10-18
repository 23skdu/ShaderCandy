#include "TestFramework.h"

#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

#include "../src/config/ConfigurationManager.h"
#include "../src/core/MathUtils.h"
#include "../src/core/PerformanceMonitor.h"
#include "../src/core/ShaderManager.h"
#include "../src/core/UniformBuffer.h"
#include "../src/platform/linux/GLSLWrapper.h"

// Coverage-closure tests.
//
// Every test here exists to exercise a specific previously-unreachable branch
// that tests/coverage.sh reports as a gap. Each one names the gap it closes,
// so a later refactor that removes the branch makes the test fail loudly
// rather than silently dropping coverage.
//
// Genuinely unreachable paths (syscall failure modes in LinuxIPC, GL loader
// failure, the localtime_r null branch) are NOT faked here. They are listed
// in docs/testing.md with the reason each cannot be triggered on this
// platform.

namespace ShaderCandy {
namespace Test {

class CoverageClosureTests : public TestSuite {
public:
  std::string getName() const override { return "Coverage Closure Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;
    results.push_back(testUniformBufferSetData());
    results.push_back(testPerformanceMonitorVariance());
    results.push_back(testZeroLengthNormalize());
    results.push_back(testConfigFloatParameterFallback());
    results.push_back(testShaderManagerReloadWithMissingFile());
    results.push_back(testShaderManagerInitializeWithoutSearchDirs());
    results.push_back(testIncludePathFallbacks());
    return results;
  }

private:
  static std::string tempDir(const char *tag) {
    std::string dir = "/tmp/shadercandy_covclose_" + std::string(tag);
    std::filesystem::remove_all(dir);
    std::filesystem::create_directories(dir);
    return dir;
  }

  static void writeFile(const std::string &path, const std::string &body) {
    const std::filesystem::path parent =
        std::filesystem::path(path).parent_path();
    if (!parent.empty()) {
      std::filesystem::create_directories(parent);
    }
    std::ofstream out(path);
    out << body;
  }

  // Gap: UniformBuffer.cpp setData() - the whole function was uncovered.
  //
  // setData() was added alongside the locking work so a caller can install a
  // whole UniformData block in one atomic write. Nothing exercised it.
  TestResult testUniformBufferSetData() {
    try {
      UniformBuffer ub;
      ub.initialize();

      UniformData d{};
      d.time = 42.0f;
      d.resolution[0] = 800.0f;
      d.resolution[1] = 600.0f;
      d.mouse[0] = 0.25f;
      d.mouse[1] = 0.75f;
      d.frame = 123;
      d.deltaTime = 0.5f;
      d.lodScale = 0.25f;
      d.maxSteps = 64;
      d.stepEpsilon = 0.005f;

      ub.setData(d);

      const auto got = ub.getData();
      TEST_ASSERT_EQUAL(42.0f, got.time);
      TEST_ASSERT_EQUAL(800.0f, got.resolution[0]);
      TEST_ASSERT_EQUAL(600.0f, got.resolution[1]);
      TEST_ASSERT_EQUAL(0.25f, got.mouse[0]);
      TEST_ASSERT_EQUAL(123, got.frame);
      TEST_ASSERT_EQUAL(64, got.maxSteps);
      TEST_ASSERT(std::fabs(got.stepEpsilon - 0.005f) < 1e-6f,
                  "setData should install stepEpsilon");

      // And the typed accessors agree with the snapshot, which is the point
      // of routing writes through setData() rather than the members.
      TEST_ASSERT_EQUAL(64, ub.getMaxSteps());
      TEST_ASSERT(std::fabs(ub.getLodScale() - 0.25f) < 1e-6f,
                  "getLodScale should agree with the snapshot");

      return {__func__, true, "UniformBuffer::setData round-trips", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // Gap: PerformanceMonitor.cpp getFrameTimeVarianceMs() - entire body
  // uncovered, because no test collected two or more frame times and asked.
  TestResult testPerformanceMonitorVariance() {
    try {
      PerformanceMonitor monitor;

      // Fewer than two frames: the documented early-out.
      TEST_ASSERT_EQUAL(0.0f, monitor.getFrameTimeVarianceMs());

      // Two identical frames produce zero variance.
      monitor.beginFrame();
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
      monitor.endFrame();
      monitor.beginFrame();
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
      monitor.endFrame();

      const float variance = monitor.getFrameTimeVarianceMs();
      TEST_ASSERT(variance >= 0.0f, "variance must not be negative");
      TEST_ASSERT(variance < 50.0f,
                  "two ~20ms frames should have small variance, got " +
                      std::to_string(variance));

      // A wildly uneven frame time must produce a strictly larger variance,
      // which proves the accumulator and mean loop actually run rather than
      // returning a constant.
      monitor.beginFrame();
      std::this_thread::sleep_for(std::chrono::milliseconds(120));
      monitor.endFrame();

      const float uneven = monitor.getFrameTimeVarianceMs();
      TEST_ASSERT(uneven > variance,
                  "adding a 120ms frame should raise variance (" +
                      std::to_string(uneven) + " vs " +
                      std::to_string(variance) + ")");

      return {__func__, true, "frame-time variance computed and ordered", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // Gap: MathUtils.h Vec2::normalize() and Vec4::normalize() zero-length
  // early-out. Both guard a division by len == 0 and return *this unchanged.
  TestResult testZeroLengthNormalize() {
    try {
      const Math::Vec2 zero2(0.0f, 0.0f);
      const Math::Vec2 n2 = zero2.normalize();
      TEST_ASSERT_EQUAL(0.0f, n2.x);
      TEST_ASSERT_EQUAL(0.0f, n2.y);
      TEST_ASSERT(std::isfinite(n2.x) && std::isfinite(n2.y),
                  "zero-length normalize must not produce NaN/Inf");

      const Math::Vec4 zero4(0.0f, 0.0f, 0.0f, 0.0f);
      const Math::Vec4 n4 = zero4.normalize();
      TEST_ASSERT_EQUAL(0.0f, n4.x);
      TEST_ASSERT_EQUAL(0.0f, n4.w);
      TEST_ASSERT(std::isfinite(n4.x) && std::isfinite(n4.w),
                  "zero-length Vec4 normalize must not produce NaN/Inf");

      // A non-zero vector still normalises, so the early-out did not
      // accidentally swallow the normal path.
      const Math::Vec2 unit = Math::Vec2(3.0f, 4.0f).normalize();
      TEST_ASSERT(std::fabs(unit.x - 0.6f) < 1e-5f, "Vec2 normalize x");
      TEST_ASSERT(std::fabs(unit.y - 0.8f) < 1e-5f, "Vec2 normalize y");

      const Math::Vec4 unit4 =
          Math::Vec4(0.0f, 0.0f, 2.0f, 0.0f).normalize();
      TEST_ASSERT(std::fabs(unit4.z - 1.0f) < 1e-5f, "Vec4 normalize z");

      return {__func__, true,
              "zero-length normalize is a no-op, non-zero still normalises",
              0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // Gap: ConfigurationManager.h getFloatParameter() - the two lines after the
  // float and int branches, reached when the stored value is neither (a bool
  // or string parameter, or an unknown name). Both must return 1.0f.
  TestResult testConfigFloatParameterFallback() {
    try {
      Config::ConfigurationManager &cm =
          Config::ConfigurationManager::getInstance();

      // Unknown parameter: getParameter returns a default, which is neither
      // float nor int, so the fallback fires.
      TEST_ASSERT_EQUAL(1.0f, cm.getFloatParameter("no_such_shader",
                                                   "no_such_param"));

      // A parameter explicitly stored as a string must also fall back rather
      // than misread the variant.
      cm.setParameter("covclose_shader", "covclose_str", "hello");
      TEST_ASSERT_EQUAL(1.0f,
                        cm.getFloatParameter("covclose_shader", "covclose_str"));

      // And an int parameter is still promoted, proving the fallback did not
      // swallow the int branch.
      cm.setParameter("covclose_shader", "covclose_int", 7);
      TEST_ASSERT(std::fabs(cm.getFloatParameter("covclose_shader",
                                                 "covclose_int") -
                            7.0f) < 1e-6f,
                  "int parameter should promote to float");

      cm.resetParameter("covclose_shader", "covclose_str");
      cm.resetParameter("covclose_shader", "covclose_int");

      return {__func__, true, "getFloatParameter fallback returns 1.0f", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // Gap: ShaderManager.cpp reloadShaders() - the `continue` for a registered
  // shader whose file has since disappeared.
  TestResult testShaderManagerReloadWithMissingFile() {
    try {
      std::string dir = tempDir("reload_missing");
      std::string path = dir + "/vanishing.frag";
      writeFile(path, "void effect_main(){}\n");

      auto sm = createShaderManager();
      TEST_ASSERT_NOT_NULL(sm.get());
      TEST_ASSERT(sm->loadShader("vanishing", path),
                  "loadShader should accept an existing file");
      sm->setHotReload(true);

      // Delete the file out from under the manager, then force a poll past
      // the throttle window.
      std::filesystem::remove(path);
      std::this_thread::sleep_for(std::chrono::milliseconds(600));
      sm->reloadShaders(); // must not throw, must not report a change
      sm->reloadShaders();

      // The name is still listed: a vanished file is skipped, not forgotten.
      const auto names = sm->getAvailableShaders();
      bool stillListed = false;
      for (const auto &n : names) {
        if (n == "vanishing") {
          stillListed = true;
        }
      }
      TEST_ASSERT(stillListed, "a missing file should be skipped, not dropped");

      std::filesystem::remove_all(dir);
      return {__func__, true, "reloadShaders tolerates a vanished file", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // Gap: ShaderManager.cpp initialize() - the early `return false` when none
  // of the relative search paths exist. Reached by running from a directory
  // that is not the repository.
  TestResult testShaderManagerInitializeWithoutSearchDirs() {
    try {
      auto sm = createShaderManager();

      const auto cwd = std::filesystem::current_path();
      std::string sandbox = tempDir("no_search_dirs");
      std::filesystem::current_path(sandbox);

      const bool found = sm->initialize();

      std::filesystem::current_path(cwd);
      std::filesystem::remove_all(sandbox);

      TEST_ASSERT(!found,
                  "initialize should return false with no search dirs present");
      TEST_ASSERT(sm->getAvailableShaders().empty(),
                  "no directories means no shaders discovered");

      return {__func__, true, "initialize reports false with no search dirs",
              0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // Gap: GLSLWrapper.h loadShaderWithIncludes() - three include-resolution
  // branches that no test reached:
  //
  //   * dir = "./"              - loading a bare filename with no slash
  //   * the ../../ strip loop   - an include that climbs two or more levels
  //   * the dir+"../../" and "./shaders/" fallback ladder
  TestResult testIncludePathFallbacks() {
    try {
      using ShaderCandy::Platform::Linux::GLSLWrapper;
      namespace fs = std::filesystem;

      // ---- Branch 1: a path with no '/' at all, so dir becomes "./". ----
      const auto cwd = fs::current_path();
      std::string sandbox = tempDir("inc");
      fs::current_path(sandbox);

      writeFile("bare.frag",
                "#version 450 core\n"
                "void effect_main(){}\n");
      GLSLWrapper::clearFileCache();
      const std::string bare = GLSLWrapper::loadShaderWithIncludes("bare.frag");
      TEST_ASSERT(bare.find("effect_main") != std::string::npos,
                  "bare filename (dir=\"./\") should load and expand");

      // ---- Branch 2/3: include climbing two levels with the ../../ fallback. ----
      //
      // Layout:
      //   root/base/common.glsl        <- the real target
      //   root/shaders/deep/leaf.frag  <- includes "../../../base/common.glsl"
      //
      // From dir "root/shaders/deep/", the ../../ ladder strips two levels,
      // leaving "base/common.glsl" relative to "root/".
      writeFile("base/common.glsl", "vec3 covclose_helper(){ return vec3(1.0); }\n");
      writeFile("shaders/deep/leaf.frag",
                "#version 450 core\n"
                "#include \"../../../base/common.glsl\"\n"
                "vec4 effect_main(){ return vec4(covclose_helper(), 1.0); }\n");
      GLSLWrapper::clearFileCache();
      const std::string leaf =
          GLSLWrapper::loadShaderWithIncludes("shaders/deep/leaf.frag");
      TEST_ASSERT(leaf.find("covclose_helper") != std::string::npos,
                  "multi-level ../ include should be resolved and inlined");
      TEST_ASSERT(leaf.find("#include") == std::string::npos,
                  "no #include should survive expansion");
      // #version is stripped by the preprocessor.
      TEST_ASSERT(leaf.find("#version") == std::string::npos,
                  "#version lines are dropped during include expansion");

      // ---- Branch 3: primary miss, then dir + "../" + includePath. ----
      writeFile("only_here.glsl", "// reached via the ../ fallback\n");
      writeFile("shaders/usesfallback.frag",
                "#version 450 core\n"
                "#include \"only_here.glsl\"\n"
                "vec4 effect_main(){ return vec4(0.0); }\n");
      GLSLWrapper::clearFileCache();
      const std::string fb = GLSLWrapper::loadShaderWithIncludes(
          "shaders/usesfallback.frag");
      TEST_ASSERT(fb.find("reached via the ../ fallback") != std::string::npos,
                  "dir+\\\"../\\\" fallback should resolve only_here.glsl");

      // ---- Branch 4: primary and ../ miss, dir + "./shaders/" hits. ----
      // That fallback is relative to the *process* CWD, so put the file at
      // <sandbox>/shaders/<name> and load it from <sandbox>.
      writeFile("shaders/via_shaders_dir.glsl", "// via ./shaders/ fallback\n");
      writeFile("deep2.frag",
                "#version 450 core\n"
                "#include \"via_shaders_dir.glsl\"\n"
                "vec4 effect_main(){ return vec4(1.0); }\n");
      GLSLWrapper::clearFileCache();
      const std::string vsh = GLSLWrapper::loadShaderWithIncludes("deep2.frag");
      TEST_ASSERT(vsh.find("via ./shaders/ fallback") != std::string::npos,
                  "\"./shaders/\" fallback should resolve via_shaders_dir.glsl");

      // ---- Cache: a second load of the same path returns identical text. ----
      GLSLWrapper::clearFileCache();
      const std::string first = GLSLWrapper::loadShaderWithIncludes("bare.frag");
      const std::string second = GLSLWrapper::loadShaderWithIncludes("bare.frag");
      TEST_ASSERT(first == second, "cached reload must return identical text");

      fs::current_path(cwd);
      std::filesystem::remove_all(sandbox);

      return {__func__, true,
              "include fallback ladder resolves at every level", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }
};

} // namespace Test
} // namespace ShaderCandy

using ShaderCandy::Test::CoverageClosureTests;
REGISTER_TEST_SUITE(CoverageClosureTests);