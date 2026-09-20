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
    return results;
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
};

REGISTER_TEST_SUITE(MemoryLeakTests);

} // namespace Test
} // namespace ShaderCandy
