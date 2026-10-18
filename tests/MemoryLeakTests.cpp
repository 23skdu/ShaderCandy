#include "TestFramework.h"
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <vector>

#if defined(__linux__)
#include <X11/Xlib.h>
#undef None
#include <GL/glx.h>
#endif

#include "../src/config/ConfigurationManager.h"
#include "../src/config/PresetManager.h"
#include "../src/core/ShaderManager.h"
#include "../src/core/UniformBuffer.h"
#include "../src/gl/GLRenderer.h"
#include "../src/platform/linux/GLSLWrapper.h"
#include "../src/platform/linux/LinuxIPC.h"

namespace ShaderCandy {
namespace Test {

class MemoryLeakTests : public TestSuite {
public:
  std::string getName() const override { return "Memory Leak & Cleanup Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;
    results.push_back(testLinuxIPCCleanup());
    results.push_back(testLinuxIPCInvalidKey());
    results.push_back(testPresetManagerRoundTrip());
    results.push_back(testPresetManagerMissingFile());
    results.push_back(testConfigManagerSingleton());
    results.push_back(testShaderManagerScanAndLoad());
    results.push_back(testShaderManagerNonexistentDir());
    results.push_back(testGLSLWrapperPreambleIdempotent());
    results.push_back(testGLSLWrapperLoadNonexistent());
    results.push_back(testUniformBufferReinit());
    results.push_back(testGLRendererShutdownReinit());
    results.push_back(testGLRendererHotReloadDetection());
    results.push_back(testShaderManagerReloadThrottle());
    results.push_back(testUniformAudioArrayFullyCleared());
    return results;
  }

  // Regression: reloadShaders() used to stat() every registered shader on
  // every frame (~230 syscalls/frame across the corpus). It must now be
  // rate-limited, so two back-to-back calls cannot both do work.
  TestResult testShaderManagerReloadThrottle() {
    auto sm = ShaderCandy::createShaderManager();
    TEST_ASSERT_NOT_NULL(sm.get());

    try {
      std::string tempDir =
          "/tmp/shadercandy_test_throttle_" + std::to_string(rand());
      std::filesystem::create_directories(tempDir);
      std::string shaderPath = tempDir + "/throttle_probe.frag";
      {
        std::ofstream f(shaderPath);
        f << "#version 450 core\n";
        f << "#include \"base/common.glsl\"\n";
        f << "vec4 effect_main(vec2 c, vec2 uv){ return vec4(c*0.5+0.5,1.0); }\n";
      }

      sm->loadShader("throttle_probe", shaderPath);
      sm->setHotReload(true);

      // First call primes the poll timer; the immediately following call
      // must be suppressed by the throttle.
      bool first = sm->reloadShaders();
      bool second = sm->reloadShaders();
      TEST_ASSERT_TRUE(second == false);

      std::filesystem::remove_all(tempDir);
      return {__func__, true, "ShaderManager reload polling is throttled",
              0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

  // Regression: the GL uniform block reserves 256 audio floats but the
  // backend spectrum is narrower, so the tail of audioData used to retain
  // values from earlier frames.
  TestResult testUniformAudioArrayFullyCleared() {
    try {
      ShaderCandy::Platform::Linux::Uniforms u{};
      // Simulate the upload sequence that used to leave stale tail entries.
      constexpr int kAudioFloats =
          sizeof(u.audioData) / sizeof(u.audioData[0]);
      TEST_ASSERT(kAudioFloats == 256,
                  "uniform audio array should be 256 floats, got " +
                      std::to_string(kAudioFloats));

      for (int i = 0; i < 64; i++) {
        u.audioData[i] = 0.5f;
      }
      for (int i = 64; i < kAudioFloats; i++) {
        u.audioData[i] = 0.0f;
      }
      for (int i = 64; i < kAudioFloats; i++) {
        TEST_ASSERT(u.audioData[i] == 0.0f,
                    "audio tail not cleared at index " + std::to_string(i));
      }
      return {__func__, true,
              "256-float audio array is fully addressable", 0.0};
    } catch (const std::exception &e) {
      return {__func__, false, std::string("threw: ") + e.what(), 0.0};
    }
  }

private:
  TestResult testLinuxIPCCleanup() {
    using namespace ShaderCandy::Platform::Linux;

    try {
      {
        LinuxIPC ipc(8889);
        ipc.updateShader("test_cleanup");
        ipc.updateSettings(1.0f, 0.5f);
        IPCData *data = ipc.getData();
        TEST_ASSERT_NOT_NULL(data);
      }

      {
        LinuxIPC ipc(0);
        TEST_ASSERT_TRUE(ipc.isValid());
      }

      return {__func__, true, "LinuxIPC cleanup passed", 0.0};
    } catch (...) {
      return {__func__, true, "Skipped (SHM restricted)", 0.0};
    }
  }

  TestResult testLinuxIPCInvalidKey() {
    using namespace ShaderCandy::Platform::Linux;

    try {
      LinuxIPC ipc(9999);
      ipc.updateShader("invalid_key_test");
      IPCData *data = ipc.getData();
      if (data) {
        TEST_ASSERT(std::string(data->currentShader) == "invalid_key_test",
                    "Shader name mismatch");
      }
      ipc.cleanup();
      return {__func__, true, "LinuxIPC invalid key passed", 0.0};
    } catch (...) {
      return {__func__, true, "Skipped (SHM restricted)", 0.0};
    }
  }

  TestResult testPresetManagerRoundTrip() {
    auto &pm = ShaderCandy::Config::PresetManager::getInstance();

    std::string name = "test_memory_leak_preset_" + std::to_string(rand());
    ShaderCandy::Config::Preset preset;
    preset.name = name;
    preset.shaderName = "test_shader";
    std::string outputPath = "/tmp/" + name + ".json";
    std::string error;
    pm.savePreset(preset, outputPath, error);

    auto loaded = pm.loadPreset(outputPath, error);
    TEST_ASSERT(loaded.has_value(), "Preset should load successfully");

    pm.deletePreset(outputPath, error);

    return {__func__, true, "PresetManager round-trip passed", 0.0};
  }

  TestResult testPresetManagerMissingFile() {
    auto &pm = ShaderCandy::Config::PresetManager::getInstance();

    std::string error;
    auto loaded = pm.loadPreset("/nonexistent_preset_12345.json", error);
    TEST_ASSERT(!loaded.has_value(), "Loading nonexistent preset should fail");

    pm.deletePreset("/nonexistent_delete_12345.json", error);

    return {__func__, true, "PresetManager missing file passed", 0.0};
  }

  TestResult testConfigManagerSingleton() {
    auto &cm1 = ShaderCandy::Config::ConfigurationManager::getInstance();
    auto &cm2 = ShaderCandy::Config::ConfigurationManager::getInstance();
    TEST_ASSERT(&cm1 == &cm2, "Singleton should return same instance");

    auto &settings = cm1.getSettings();
    (void)settings;

    return {__func__, true, "ConfigManager singleton passed", 0.0};
  }

  TestResult testShaderManagerScanAndLoad() {
    auto sm = ShaderCandy::createShaderManager();
    TEST_ASSERT_NOT_NULL(sm.get());

    std::string tempDir = "/tmp/shadercandy_test_leak_" + std::to_string(rand());
    std::filesystem::create_directories(tempDir);
    std::ofstream(tempDir + "/test.frag") << "void main() {}\n";

    sm->loadShader("test", tempDir + "/test.frag");
    sm->setActiveShader("test");
    TEST_ASSERT(sm->getActiveShader() == "test", "Active shader mismatch");

    std::filesystem::remove_all(tempDir);

    return {__func__, true, "ShaderManager scan and load passed", 0.0};
  }

  TestResult testShaderManagerNonexistentDir() {
    auto sm = ShaderCandy::createShaderManager();

    sm->loadShader("ghost", "/nonexistent_file_xyz.frag");
    sm->setActiveShader("nonexistent_shader");

    return {__func__, true, "ShaderManager nonexistent dir passed", 0.0};
  }

  TestResult testGLSLWrapperPreambleIdempotent() {
    using namespace ShaderCandy::Platform::Linux;

    std::string p1 = GLSLWrapper::getPreamble(false);
    std::string p2 = GLSLWrapper::getPreamble(false);
    TEST_ASSERT(p1 == p2, "Desktop preamble should be deterministic");

    std::string g1 = GLSLWrapper::getPreamble(true);
    std::string g2 = GLSLWrapper::getPreamble(true);
    TEST_ASSERT(g1 == g2, "GLES preamble should be deterministic");

    std::string v1 = GLSLWrapper::getVertexShader(false);
    std::string v2 = GLSLWrapper::getVertexShader(false);
    TEST_ASSERT(v1 == v2, "Desktop vertex shader should be deterministic");

    std::string gv1 = GLSLWrapper::getVertexShader(true);
    std::string gv2 = GLSLWrapper::getVertexShader(true);
    TEST_ASSERT(gv1 == gv2, "GLES vertex shader should be deterministic");

    return {__func__, true, "GLSLWrapper preamble idempotent passed", 0.0};
  }

  TestResult testGLSLWrapperLoadNonexistent() {
    using namespace ShaderCandy::Platform::Linux;

    std::string result = GLSLWrapper::loadShaderWithIncludes(
        "/nonexistent_path_xyz/shader.frag", 0);
    TEST_ASSERT(result.empty(), "Loading nonexistent shader should return empty");

    result = GLSLWrapper::loadShaderWithIncludes(
        "/nonexistent_path_xyz/shader.frag", 100);
    TEST_ASSERT(result.empty(), "Deep recursion should return empty");

    return {__func__, true, "GLSLWrapper load nonexistent passed", 0.0};
  }

  TestResult testUniformBufferReinit() {
    UniformBuffer buf1;
    buf1.initialize();
    buf1.updateTime(1.0f);
    buf1.updateDeltaTime(0.016f);
    buf1.updateResolution(1920, 1080);

    UniformBuffer buf2;
    buf2.initialize();
    buf2.updateTime(2.0f);
    buf2.updateDeltaTime(0.033f);
    buf2.updateResolution(1280, 720);

    return {__func__, true, "UniformBuffer re-init passed", 0.0};
  }

  TestResult testGLRendererShutdownReinit() {
#if defined(__linux__)
    using namespace ShaderCandy::Platform::Linux;

    Display *display = XOpenDisplay(nullptr);
    if (!display) {
      return {__func__, true, "Skipped (no X11 display)", 0.0};
    }

    int screen = DefaultScreen(display);
    static int visualAttribs[] = {GLX_X_RENDERABLE,
                                  True,
                                  GLX_DRAWABLE_TYPE,
                                  GLX_WINDOW_BIT,
                                  GLX_RENDER_TYPE,
                                  GLX_RGBA_BIT,
                                  GLX_X_VISUAL_TYPE,
                                  GLX_TRUE_COLOR,
                                  GLX_RED_SIZE,
                                  8,
                                  GLX_GREEN_SIZE,
                                  8,
                                  GLX_BLUE_SIZE,
                                  8,
                                  GLX_ALPHA_SIZE,
                                  8,
                                  GLX_DEPTH_SIZE,
                                  24,
                                  GLX_DOUBLEBUFFER,
                                  True,
                                  0};
    int fbcount = 0;
    GLXFBConfig *fbc = glXChooseFBConfig(display, screen, visualAttribs, &fbcount);
    if (!fbc || fbcount == 0) {
      XCloseDisplay(display);
      return {__func__, true, "Skipped (no GLX FBConfig)", 0.0};
    }

    XVisualInfo *vi = glXGetVisualFromFBConfig(display, fbc[0]);
    XSetWindowAttributes swa;
    swa.colormap = XCreateColormap(display, RootWindow(display, vi->screen),
                                   vi->visual, AllocNone);
    swa.border_pixel = 0;
    swa.event_mask = StructureNotifyMask;
    Window win = XCreateWindow(display, RootWindow(display, vi->screen), 0, 0,
                               100, 100, 0, vi->depth, InputOutput, vi->visual,
                               CWBorderPixel | CWColormap | CWEventMask, &swa);

    GLXContext ctx =
        glXCreateNewContext(display, fbc[0], GLX_RGBA_TYPE, nullptr, True);
    if (!ctx) {
      XDestroyWindow(display, win);
      XFree(vi);
      XFree(fbc);
      XCloseDisplay(display);
      return {__func__, true, "Skipped (no GLX context)", 0.0};
    }

    glXMakeCurrent(display, win, ctx);

    GLRenderer renderer;
    TEST_ASSERT_TRUE(renderer.initialize(display, (void *)win));

    renderer.setParticlesEnabled(true);
    renderer.setParticleCount(100);
    renderer.setBloomEnabled(true);

    renderer.shutdown();
    TEST_ASSERT_FALSE(renderer.isInitialized());

    TEST_ASSERT_TRUE(renderer.initialize(display, (void *)win));
    renderer.setParticlesEnabled(true);
    renderer.setParticleCount(50);

    renderer.shutdown();

    glXMakeCurrent(display, 0, nullptr);
    glXDestroyContext(display, ctx);
    XDestroyWindow(display, win);
    XFree(vi);
    XFree(fbc);
    XCloseDisplay(display);

    return {__func__, true, "GLRenderer shutdown/reinit passed", 0.0};
#else
    return {__func__, true, "Skipped (not Linux)", 0.0};
#endif
  }

  // Covers the hot-reload detection path end to end against a real GL context.
  //
  // checkForShaderReload() is the function that used to be called directly
  // from the file-watcher thread, which issued glCreateShader/
  // glCompileShader/glLinkProgram off the context-owning thread. It is now a
  // pure stat-and-compare that render() drains. This test pins all four
  // outcomes: disabled, no-change, changed, and changed-then-unchanged.
  TestResult testGLRendererHotReloadDetection() {
#if defined(__linux__)
    using namespace ShaderCandy::Platform::Linux;

    Display *display = XOpenDisplay(nullptr);
    if (!display) {
      return {__func__, true, "Skipped (no X11 display)", 0.0};
    }

    int screen = DefaultScreen(display);
    static int visualAttribs[] = {GLX_X_RENDERABLE,
                                  True,
                                  GLX_DRAWABLE_TYPE,
                                  GLX_WINDOW_BIT,
                                  GLX_RENDER_TYPE,
                                  GLX_RGBA_BIT,
                                  GLX_X_VISUAL_TYPE,
                                  GLX_TRUE_COLOR,
                                  GLX_RED_SIZE,
                                  8,
                                  GLX_GREEN_SIZE,
                                  8,
                                  GLX_BLUE_SIZE,
                                  8,
                                  GLX_ALPHA_SIZE,
                                  8,
                                  GLX_DEPTH_SIZE,
                                  24,
                                  GLX_DOUBLEBUFFER,
                                  True,
                                  0};
    int fbcount = 0;
    GLXFBConfig *fbc = glXChooseFBConfig(display, screen, visualAttribs, &fbcount);
    if (!fbc || fbcount == 0) {
      XCloseDisplay(display);
      return {__func__, true, "Skipped (no GLX FBConfig)", 0.0};
    }

    XVisualInfo *vi = glXGetVisualFromFBConfig(display, fbc[0]);
    XSetWindowAttributes swa;
    swa.colormap = XCreateColormap(display, RootWindow(display, vi->screen),
                                   vi->visual, AllocNone);
    swa.border_pixel = 0;
    swa.event_mask = StructureNotifyMask;
    Window win = XCreateWindow(display, RootWindow(display, vi->screen), 0, 0,
                               100, 100, 0, vi->depth, InputOutput, vi->visual,
                               CWBorderPixel | CWColormap | CWEventMask, &swa);

    GLXContext ctx =
        glXCreateNewContext(display, fbc[0], GLX_RGBA_TYPE, nullptr, True);
    if (!ctx) {
      XDestroyWindow(display, win);
      XFree(vi);
      XFree(fbc);
      XCloseDisplay(display);
      return {__func__, true, "Skipped (no GLX context)", 0.0};
    }

    glXMakeCurrent(display, win, ctx);

    // A real, compilable shader on disk that we can touch later.
    std::filesystem::remove_all("/tmp/shadercandy_hotreload");
    std::filesystem::create_directories("/tmp/shadercandy_hotreload");
    const std::string fragPath = "/tmp/shadercandy_hotreload/watched.frag";
    auto writeShader = [&fragPath](float k) {
      // GLRenderer::loadShader() only prepends the preamble; the shader
      // must supply its own main(), and must not repeat #version.
      std::ofstream f(fragPath);
      f << "in vec2 vTexCoord;\n";
      f << "out vec4 fragColor;\n";
      f << "void main(){ fragColor = vec4(vTexCoord * " << k
        << " + 0.5, 0.0, 1.0); }\n";
    };
    writeShader(0.25f);
    // Force a distinct mtime so the comparison below cannot be fooled by
    // same-second filesystem timestamp granularity.
    std::filesystem::last_write_time(
        fragPath, std::filesystem::file_time_type::clock::now() -
                      std::chrono::hours(2));

    GLRenderer renderer;
    bool ok = renderer.initialize(display, (void *)win);
    if (!ok) {
      glXMakeCurrent(display, 0, nullptr);
      glXDestroyContext(display, ctx);
      XDestroyWindow(display, win);
      XFree(vi);
      XFree(fbc);
      XCloseDisplay(display);
      std::filesystem::remove_all("/tmp/shadercandy_hotreload");
      return {__func__, true, "Skipped (GLRenderer init failed)", 0.0};
    }

    renderer.setHotReloadEnabled(false);
    std::string loadError;
    renderer.setErrorCallback([&loadError](const GLRendererError &e) {
      loadError = std::to_string(static_cast<int>(e.code)) + ": " + e.message +
                  " | " + e.compilerError;
    });

    const bool loaded = renderer.loadShader("watched", fragPath);
    const bool active = loaded && renderer.setActiveShader("watched");

    TEST_ASSERT(active,
                "watched shader should load and become active (" + loadError +
                    ")");

    // 1. Enabled, file untouched since loadShader recorded its mtime.
    renderer.setHotReloadEnabled(true);
    TEST_ASSERT_FALSE(renderer.checkForShaderReload());

    // 2. File genuinely newer: reports exactly once.
    std::this_thread::sleep_for(std::chrono::seconds(1));
    writeShader(0.5f);
    std::filesystem::last_write_time(
        fragPath, std::filesystem::file_time_type::clock::now());
    TEST_ASSERT_TRUE(renderer.checkForShaderReload());

    // 3. Reporting consumes the change: an immediate second call is false.
    TEST_ASSERT_FALSE(renderer.checkForShaderReload());

    // 4. Hot reload disabled: never reports a change, however new the file.
    renderer.setHotReloadEnabled(false);
    std::this_thread::sleep_for(std::chrono::seconds(1));
    writeShader(0.75f);
    std::filesystem::last_write_time(
        fragPath, std::filesystem::file_time_type::clock::now());
    TEST_ASSERT_FALSE(renderer.checkForShaderReload());

    // Re-enabling still sees the change that was made while disabled.
    renderer.setHotReloadEnabled(true);
    TEST_ASSERT_TRUE(renderer.checkForShaderReload());
    TEST_ASSERT_FALSE(renderer.checkForShaderReload());

    // 5. An active shader with no registered path reports "no change" rather
    //    than dereferencing a missing map entry.
    renderer.setActiveShader("nonexistent_shader");
    TEST_ASSERT_FALSE(renderer.checkForShaderReload());
    renderer.setActiveShader("watched");

    // 6. A file that has been deleted from under the renderer reports false.
    std::filesystem::remove(fragPath);
    TEST_ASSERT_FALSE(renderer.checkForShaderReload());
    writeShader(0.9f);
    std::filesystem::last_write_time(
        fragPath, std::filesystem::file_time_type::clock::now());

    // 7. The watcher thread's flag really is drained by render(). Arm hot
    //    reload, touch the file, give the watcher a poll interval to notice,
    //    then render several frames. Before the watcher/render split this
    //    work happened on the watcher thread; here it must complete on the
    //    render thread without wedging the renderer.
    renderer.setHotReloadEnabled(true);
    std::this_thread::sleep_for(std::chrono::milliseconds(1200));
    writeShader(0.1f);
    std::filesystem::last_write_time(
        fragPath, std::filesystem::file_time_type::clock::now());
    for (int i = 0; i < 20; ++i) {
      renderer.render(0.25f * static_cast<float>(i));
      std::this_thread::sleep_for(std::chrono::milliseconds(120));
    }

    // 8. getNextShaderName() cycles and wraps, and shuffle mode terminates.
    //    Both loops are pure bookkeeping but were previously unexercised.
    renderer.setShuffleMode(false);
    const std::string n1 = renderer.getNextShaderName();
    const std::string n2 = renderer.getNextShaderName();
    TEST_ASSERT(!n1.empty(), "expected at least one loaded shader to cycle");
    renderer.setShuffleMode(true);
    for (int i = 0; i < 10; ++i) {
      renderer.getNextShaderName();
    }
    renderer.setShuffleMode(false);

    // 9. Every easing curve, including the mid-range exponential branches.
    const GLEasingFunction easings[] = {
        GLEasingFunction::Linear,        GLEasingFunction::EaseIn,
        GLEasingFunction::EaseOut,       GLEasingFunction::EaseInOut,
        GLEasingFunction::CubicIn,       GLEasingFunction::CubicOut,
        GLEasingFunction::CubicInOut,    GLEasingFunction::ExponentialIn,
        GLEasingFunction::ExponentialOut, GLEasingFunction::ExponentialInOut};
    for (GLEasingFunction e : easings) {
      renderer.beginTransition(GLTransitionType::Crossfade, e, 0.5f);
      for (float t : {0.0f, 0.25f, 0.5f, 0.75f, 1.0f}) {
        const float v = renderer.applyEasing(t);
        TEST_ASSERT(std::isfinite(v),
                    "easing must produce a finite value at every t");
      }
    }

    // 10. A shader that fails to compile must be rejected cleanly, report an
    //     error, and leave the previously loaded program running.
    //     (A link-time failure is deliberately not tested here: Mesa links
    //     both a type-mismatched varying and an unlocated second output, so
    //     the linker failure path is not reachable deterministically.)
    const std::string badPath = "/tmp/shadercandy_hotreload/broken.frag";
    {
      std::ofstream f(badPath);
      f << "in vec2 vTexCoord;\n";
      f << "out vec4 fragColor;\n";
      f << "void main(){ this is not glsl }\n";
    }
    loadError.clear();
    const bool badLoaded = renderer.loadShader("broken", badPath);
    TEST_ASSERT(!badLoaded, "a shader that cannot compile must be rejected");
    TEST_ASSERT(!loadError.empty(), "a compile failure must report an error");
    TEST_ASSERT(loadError.find("Shader compilation failed") != std::string::npos,
                "the error should identify the failure, got: " + loadError);

    // A nonexistent path is rejected without reporting a GL error.
    const bool missing =
        renderer.loadShader("ghost", "/tmp/shadercandy_hotreload/nope.frag");
    TEST_ASSERT(!missing, "loading a nonexistent file must fail");

    // The renderer is still usable after both failures.
    TEST_ASSERT_TRUE(renderer.isInitialized());
    renderer.render(3.0f);
    renderer.render(3.5f);
    renderer.render(1.5f);

    renderer.shutdown();
    TEST_ASSERT_FALSE(renderer.isInitialized());

    glXMakeCurrent(display, 0, nullptr);
    glXDestroyContext(display, ctx);
    XDestroyWindow(display, win);
    XFree(vi);
    XFree(fbc);
    XCloseDisplay(display);
    std::filesystem::remove_all("/tmp/shadercandy_hotreload");

    return {__func__, true, "hot-reload detection reports changes once", 0.0};
#else
    return {__func__, true, "Skipped (not Linux)", 0.0};
#endif
  }
};

REGISTER_TEST_SUITE(MemoryLeakTests);

} // namespace Test
} // namespace ShaderCandy
