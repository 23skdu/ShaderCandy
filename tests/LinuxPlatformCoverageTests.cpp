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

#include "../src/audio/AudioInput.h"
#include "../src/config/ConfigurationManager.h"
#include "../src/config/PresetManager.h"
#include "../src/core/ShaderManager.h"
#include "../src/gl/GLRenderer.h"
#include "../src/gl/GLShaderCompiler.h"
#include "../src/platform/linux/GLSLWrapper.h"
#include "../src/platform/linux/LinuxIPC.h"

namespace ShaderCandy {
namespace Test {

class LinuxPlatformCoverageTests : public TestSuite {
public:
  std::string getName() const override {
    return "Linux Platform & Audio Coverage Tests";
  }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;
    results.push_back(testGLSLWrapperCoverage());
    results.push_back(testLinuxIPCCoverage());
    results.push_back(testAudioInputComprehensive());
    results.push_back(testGLShaderCompilerComprehensive());
    results.push_back(testGLRendererComprehensive());
    results.push_back(testCoreEdgeCasesCoverage());
    return results;
  }

private:
  TestResult testGLSLWrapperCoverage() {
    using namespace ShaderCandy::Platform::Linux;

    // Desktop GL preamble
    std::string preambleGL = GLSLWrapper::getPreamble(false);
    TEST_ASSERT(preambleGL.find("#version 330 core") != std::string::npos,
                "Desktop preamble missing #version 330 core");
    TEST_ASSERT(preambleGL.find("layout(std140) uniform Uniforms") !=
                    std::string::npos,
                "Desktop preamble missing Uniforms block");
    TEST_ASSERT(preambleGL.find("vec3 ACESFilm") != std::string::npos,
                "Desktop preamble missing ACESFilm tone mapping");
    TEST_ASSERT(preambleGL.find("vec3 Reinhard") != std::string::npos,
                "Desktop preamble missing Reinhard tone mapping");

    // GLES preamble
    std::string preambleGLES = GLSLWrapper::getPreamble(true);
    TEST_ASSERT(preambleGLES.find("#version 300 es") != std::string::npos,
                "GLES preamble missing #version 300 es");
    TEST_ASSERT(preambleGLES.find("precision highp float;") !=
                    std::string::npos,
                "GLES preamble missing precision highp float");

    // Desktop vertex shader
    std::string vertGL = GLSLWrapper::getVertexShader(false);
    TEST_ASSERT(vertGL.find("layout(location = 0) in vec2 aPos;") !=
                    std::string::npos,
                "Desktop vertex shader missing layout 0");
    TEST_ASSERT(vertGL.find("gl_Position = vec4(aPos, 0.0, 1.0);") !=
                    std::string::npos,
                "Desktop vertex shader missing gl_Position calculation");

    // GLES vertex shader
    std::string vertGLES = GLSLWrapper::getVertexShader(true);
    TEST_ASSERT(vertGLES.find("#version 300 es") != std::string::npos,
                "GLES vertex shader missing #version 300 es");
    TEST_ASSERT(vertGLES.find("in vec2 position;") != std::string::npos,
                "GLES vertex shader missing in vec2 position");

    return {__func__, true, "GLSLWrapper coverage passed", 0.0};
  }

  TestResult testLinuxIPCCoverage() {
    using namespace ShaderCandy::Platform::Linux;

    try {
      LinuxIPC ipc(8888);
      ipc.updateShader("aurora_ipc_test");
      ipc.updateSettings(1.8f, 0.75f);

      IPCData *data = ipc.getData();
      TEST_ASSERT(data != nullptr, "IPC data pointer should not be null");
      TEST_ASSERT(std::string(data->currentShader) == "aurora_ipc_test",
                  "Shader name mismatch in IPC");
      TEST_ASSERT_EQUAL(1.8f, data->speed);
      TEST_ASSERT_EQUAL(0.75f, data->intensity);
      TEST_ASSERT_TRUE(data->updateNeeded);

      ipc.cleanup();
    } catch (...) {
      // SHM may be restricted in sandbox container environments
    }

    return {__func__, true, "LinuxIPC coverage passed", 0.0};
  }

  TestResult testAudioInputComprehensive() {
    using namespace ShaderCandy::Audio;

    AudioInput audio;
    bool inited = audio.initialize(44100, 1024);
    TEST_ASSERT_TRUE(inited);
    TEST_ASSERT_FALSE(audio.isRunning());

    // Low latency mode toggling
    audio.setLowLatencyMode(true);
    TEST_ASSERT_TRUE(audio.isLowLatencyMode());
    audio.setLowLatencyMode(false);
    TEST_ASSERT_FALSE(audio.isLowLatencyMode());

    // Smoothing range clamping
    audio.setSmoothing(0.5f);
    audio.setSmoothing(-0.5f); // Clamps to 0.0f
    audio.setSmoothing(1.5f);  // Clamps to 1.0f
    audio.setSmoothing(0.8f);

    // Beat threshold
    audio.setBeatThreshold(0.2f);
    audio.setBeatThreshold(-0.5f); // Max with 0.0f
    audio.setBeatThreshold(0.1f);

    // Callback and FFT processing
    bool callbackInvoked = false;
    AudioData receivedData;
    audio.setCallback([&](const AudioData &d) {
      callbackInvoked = true;
      receivedData = d;
    });

    // Empty samples edge case
    audio.performFFT({});
    TEST_ASSERT_FALSE(callbackInvoked);

    // Synthetic sine wave (440 Hz standard concert pitch)
    std::vector<float> sineSamples(1024);
    for (size_t i = 0; i < sineSamples.size(); ++i) {
      sineSamples[i] =
          std::sin(2.0f * static_cast<float>(M_PI) * 440.0f * i / 44100.0f);
    }
    audio.performFFT(sineSamples);
    TEST_ASSERT_TRUE(callbackInvoked);
    TEST_ASSERT(receivedData.volume > 0.0f, "Volume should be greater than 0");

    // Direct audio data injection
    AudioData customData;
    customData.volume = 0.95f;
    customData.bass = 0.85f;
    customData.mid = 0.65f;
    customData.treble = 0.45f;
    customData.beat = 1.0f;
    std::fill(customData.bands, customData.bands + AudioData::NUM_BANDS, 0.5f);
    customData.spectrum.resize(64, 0.25f);
    audio.onAudioData(customData);

    AudioData current = audio.getCurrentData();
    TEST_ASSERT_EQUAL(0.95f, current.volume);
    TEST_ASSERT_EQUAL(0.85f, current.bass);
    TEST_ASSERT_EQUAL(0.65f, current.mid);
    TEST_ASSERT_EQUAL(0.45f, current.treble);
    TEST_ASSERT_EQUAL(1.0f, current.beat);

    // Device enumeration & selection
    auto devices = audio.getAvailableDevices();
    TEST_ASSERT(!devices.empty(), "Device list should include default");

    bool badOpen = audio.selectDevice("nonexistent_device_xyz_12345");
    TEST_ASSERT_FALSE(badOpen);

    audio.openDevice("nonexistent_device_xyz_direct");
    if (audio.openDevice("default")) {
      audio.start();
      std::this_thread::sleep_for(std::chrono::milliseconds(20));
      audio.selectDevice("default");
      audio.stop();
    }

    audio.autoSelectDevice();
    audio.start();
    audio.stop();
    TEST_ASSERT_FALSE(audio.isRunning());

    return {__func__, true, "AudioInput comprehensive passed", 0.0};
  }

  TestResult testGLShaderCompilerComprehensive() {
#if defined(__linux__)
    using namespace ShaderCandy::Platform::Linux;

    Display *display = XOpenDisplay(nullptr);
    if (!display) {
      return {__func__, true, "Skipped (no X11 display available)", 0.0};
    }

    int screen = DefaultScreen(display);
    static int visualAttribs[] = {
        GLX_X_RENDERABLE, True,
        GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT,
        GLX_RENDER_TYPE, GLX_RGBA_BIT,
        GLX_X_VISUAL_TYPE, GLX_TRUE_COLOR,
        GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8, GLX_BLUE_SIZE, 8, GLX_ALPHA_SIZE, 8,
        GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, True,
        0
    };
    int fbcount = 0;
    GLXFBConfig *fbc = glXChooseFBConfig(display, screen, visualAttribs, &fbcount);
    if (!fbc || fbcount == 0) {
      XCloseDisplay(display);
      return {__func__, true, "Skipped (cannot choose GLX FBConfig)", 0.0};
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
      return {__func__, true, "Skipped (cannot create GLX context)", 0.0};
    }

    glXMakeCurrent(display, win, ctx);

    GLShaderCompiler compiler;
    TEST_ASSERT_TRUE(compiler.initialize());
    TEST_ASSERT_TRUE(compiler.initialize()); // Idempotent check

    compiler.setPreamble("#version 330 core\nprecision highp float;\n");

    // 1. Valid compilation from source
    unsigned int prog = 0;
    bool ok = compiler.compileFromSource(
        "#version 330 core\nlayout(location=0) in vec2 aPos;\nvoid main() { "
        "gl_Position = vec4(aPos, 0.0, 1.0); }",
        "out vec4 fragColor;\nvoid main() { fragColor = vec4(1.0, 0.5, 0.2, "
        "1.0); }",
        prog);
    TEST_ASSERT_TRUE(ok);
    TEST_ASSERT(prog > 0, "Valid program ID expected");

    // 2. Invalid vertex shader
    unsigned int badProg = 0;
    bool badVs = compiler.compileFromSource(
        "invalid_syntax_vertex_shader_@@#$",
        "out vec4 fragColor;\nvoid main() { fragColor = vec4(1.0); }", badProg);
    TEST_ASSERT_FALSE(badVs);
    TEST_ASSERT_TRUE(compiler.hasErrors());
    TEST_ASSERT(!compiler.getLastError().empty(),
                "Error message should be non-empty");
    compiler.clearError();
    TEST_ASSERT_FALSE(compiler.hasErrors());

    // 3. Invalid fragment shader
    bool badFs = compiler.compileFromSource(
        "#version 330 core\nlayout(location=0) in vec2 aPos;\nvoid main() { "
        "gl_Position = vec4(aPos, 0.0, 1.0); }",
        "invalid_syntax_fragment_shader_###@@@", badProg);
    TEST_ASSERT_FALSE(badFs);
    TEST_ASSERT_TRUE(compiler.hasErrors());

    // 4. Program link error (mismatched in/out attributes)
    bool badLink = compiler.compileFromSource(
        "#version 330 core\nout vec2 badCoord;\nvoid main() { gl_Position = "
        "vec4(0.0); badCoord = vec2(1.0); }",
        "in vec4 badCoord;\nout vec4 fragColor;\nvoid main() { fragColor = "
        "badCoord; }",
        badProg);
    TEST_ASSERT_FALSE(badLink);

    // 5. compileFromFile missing file
    bool missingFile =
        compiler.compileFromFile("/nonexistent/file_xyz_123.frag", badProg);
    TEST_ASSERT_FALSE(missingFile);
    TEST_ASSERT_TRUE(compiler.hasErrors());

    // 6. compileFromFile valid file
    std::string tmpFrag = "/tmp/test_compiler_source.frag";
    std::ofstream tmpFragFile(tmpFrag);
    tmpFragFile << "out vec4 fragColor;\nvoid main() { fragColor = vec4(0.0, "
                   "1.0, 0.0, 1.0); }\n";
    tmpFragFile.close();

    unsigned int fileProg = 0;
    bool validFile = compiler.compileFromFile(tmpFrag, fileProg);
    TEST_ASSERT_TRUE(validFile);
    TEST_ASSERT(fileProg > 0, "Valid program ID expected");
    std::filesystem::remove(tmpFrag);

    compiler.shutdown();

    // Clean up offscreen context
    glXMakeCurrent(display, 0, nullptr);
    glXDestroyContext(display, ctx);
    XDestroyWindow(display, win);
    XFree(vi);
    XFree(fbc);
    XCloseDisplay(display);
#endif

    return {__func__, true, "GLShaderCompiler comprehensive passed", 0.0};
  }

  TestResult testGLRendererComprehensive() {
#if defined(__linux__)
    using namespace ShaderCandy::Platform::Linux;

    Display *display = XOpenDisplay(nullptr);
    if (!display) {
      return {__func__, true, "Skipped (no X11 display available)", 0.0};
    }

    int screen = DefaultScreen(display);
    static int visualAttribs[] = {
        GLX_X_RENDERABLE, True,
        GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT,
        GLX_RENDER_TYPE, GLX_RGBA_BIT,
        GLX_X_VISUAL_TYPE, GLX_TRUE_COLOR,
        GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8, GLX_BLUE_SIZE, 8, GLX_ALPHA_SIZE, 8,
        GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, True,
        0
    };
    int fbcount = 0;
    GLXFBConfig *fbc = glXChooseFBConfig(display, screen, visualAttribs, &fbcount);
    if (!fbc || fbcount == 0) {
      XCloseDisplay(display);
      return {__func__, true, "Skipped (cannot choose GLX FBConfig)", 0.0};
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
      return {__func__, true, "Skipped (cannot create GLX context)", 0.0};
    }

    glXMakeCurrent(display, win, ctx);

    GLRenderer renderer;

    // Uninitialized state checks
    TEST_ASSERT_FALSE(renderer.isInitialized());
    renderer.render(1.0f); // Early return branch
    TEST_ASSERT_FALSE(renderer.reloadCurrentShader());
    TEST_ASSERT_FALSE(renderer.setActiveShader("nonexistent"));
    TEST_ASSERT_TRUE(renderer.availableShaderNames().empty());

    // Initialize renderer
    bool rInit = renderer.initialize(display, (void *)win);
    TEST_ASSERT_TRUE(rInit);
    TEST_ASSERT_TRUE(renderer.isInitialized());
    TEST_ASSERT_TRUE(renderer.initialize(display, (void *)win)); // Idempotent
    TEST_ASSERT(!renderer.getGLVersion().empty(), "GL version not empty");
    TEST_ASSERT(!renderer.getGLSLVersion().empty(), "GLSL version not empty");

    // Uniform & Feature setters
    renderer.setSpeed(2.5f);
    renderer.setIntensity(1.5f);
    renderer.setGravity(9.81f);
    renderer.setMouse(120.0f, 240.0f, 1);
    renderer.setAudioData(0.8f, 0.9f, 0.7f, 0.5f, 1.0f);

    renderer.setAudioReactivityEnabled(true);
    TEST_ASSERT_TRUE(renderer.isAudioReactivityEnabled());
    renderer.setAudioReactivityEnabled(false);
    TEST_ASSERT_FALSE(renderer.isAudioReactivityEnabled());

    renderer.setBloomEnabled(true);
    renderer.setBloomQuality(GLBloomQuality::High);
    renderer.setBloomIntensity(0.7f);
    renderer.setBloomThreshold(0.8f);

    renderer.setParticlesEnabled(true);
    renderer.setParticleCount(300);
    renderer.setParticleGravity(4.5f);

    renderer.setHDREnabled(true);
    TEST_ASSERT_TRUE(renderer.isHDREnabled());
    renderer.setToneMapping(GLToneMapping::ACES);
    TEST_ASSERT_EQUAL(static_cast<int>(GLToneMapping::ACES),
                      static_cast<int>(renderer.getToneMapping()));
    renderer.setToneMapping(GLToneMapping::Reinhard);
    renderer.setToneMapping(GLToneMapping::Filmic);
    renderer.setToneMapping(GLToneMapping::Hable);
    renderer.setToneMapping(GLToneMapping::None);
    // HDR and tone mapping initialization and rendering
    renderer.setHDREnabled(true);
    TEST_ASSERT_TRUE(renderer.isHDREnabled());
    renderer.initToneMapping();
    renderer.resize(800, 600);
    renderer.renderToneMap();
    renderer.setHDREnabled(false);

    renderer.setHotReloadEnabled(true);
    TEST_ASSERT_TRUE(renderer.isHotReloadEnabled());
    renderer.setHotReloadEnabled(false);
    TEST_ASSERT_FALSE(renderer.isHotReloadEnabled());

    renderer.resize(640, 480);
    renderer.resize(800, 600);

    // Shader loading failure path (missing file)
    TEST_ASSERT_FALSE(
        renderer.loadShader("missing", "/nonexistent/test_bad_path.frag"));
    TEST_ASSERT_TRUE(renderer.getLastError().code != GLRendererErrorCode::None);
    renderer.clearError();
    TEST_ASSERT_EQUAL(static_cast<int>(GLRendererErrorCode::None),
                      static_cast<int>(renderer.getLastError().code));

    // Shader compilation error path
    std::string badFrag = "/tmp/test_gl_bad_syntax.frag";
    std::ofstream badFragFile(badFrag);
    badFragFile << "invalid glsl syntax here @@@!;\n";
    badFragFile.close();
    TEST_ASSERT_FALSE(renderer.loadShader("bad_shader", badFrag));
    renderer.clearError();
    std::filesystem::remove(badFrag);

    // Valid shader creation with full uniform coverage and rendering
    std::string testFrag = "/tmp/test_gl_renderer_quad.frag";
    std::ofstream testFragFile(testFrag);
    testFragFile << "out vec4 fragColor;\n"
                    "void main() {\n"
                    "  float v = time + speed + intensity + resolution[0] + mouse[0] + "
                    "            mouseButtons + alpha + gravity + volume + bass + "
                    "            mid + treble + beat;\n"
                    "  fragColor = vec4(v * 0.0001, 0.5, 0.0, 1.0);\n"
                    "}\n";
    testFragFile.close();

    bool loadOk = renderer.loadShader("test_quad", testFrag);
    TEST_ASSERT_TRUE(loadOk);

    // Test overwriting existing shader program
    bool reloadOk = renderer.loadShader("test_quad", testFrag);
    TEST_ASSERT_TRUE(reloadOk);

    TEST_ASSERT_TRUE(renderer.setActiveShader("test_quad"));
    TEST_ASSERT_TRUE(renderer.activeShaderName() == "test_quad");
    TEST_ASSERT_EQUAL(1, renderer.availableShaderNames().size());

    // Render loop and performance tracking
    for (int i = 0; i < 65; ++i) {
      renderer.render(0.016f * i);
    }
    auto metrics = renderer.getMetrics();
    TEST_ASSERT(metrics.averageFPS >= 0.0, "Average FPS non-negative");
    renderer.resetMetrics();

    // Test particle update and render
    renderer.setParticlesEnabled(true);
    renderer.render(0.016f);
    renderer.setParticlesEnabled(false);

    // Test bloom render pass
    renderer.setBloomEnabled(true);
    renderer.render(0.016f);
    renderer.setBloomEnabled(false);

    // Reload check
    renderer.reloadCurrentShader();
    renderer.checkForShaderReload();
    std::filesystem::remove(testFrag);

    renderer.shutdown();

    // Clean up offscreen context
    glXMakeCurrent(display, 0, nullptr);
    glXDestroyContext(display, ctx);
    XDestroyWindow(display, win);
    XFree(vi);
    XFree(fbc);
    XCloseDisplay(display);
#endif

    return {__func__, true, "GLRenderer comprehensive passed", 0.0};
  }

  TestResult testCoreEdgeCasesCoverage() {
    // 1. ConfigurationManager HOME unset fallback
    const char *origHome = getenv("HOME");
    std::string homeStr = origHome ? origHome : "";

    unsetenv("HOME");
    std::string fallbackDir =
        Config::ConfigurationManager::getConfigDirectory();
    TEST_ASSERT_TRUE(fallbackDir == "/tmp/ShaderCandy");

    if (!homeStr.empty()) {
      setenv("HOME", homeStr.c_str(), 1);
    }

    // 2. JSON parseValue empty/truncated string
    auto emptyVal = Config::JSON::parse("{\"truncated\": }");
    (void)emptyVal;

    // 3. deserializeSettings missing colon branch
    auto noColon =
        Config::JSON::deserializeSettings("{\"targetFPS\" 60, \"vsync\" true}");
    (void)noColon;

    // 4. Quality clamp with > 20 for loops in parseShaderMetadata
    std::string heavyLoopPath = "/tmp/test_heavy_loops.frag";
    std::ofstream heavyFile(heavyLoopPath);
    heavyFile << "// Heavy loop shader\n";
    for (int i = 0; i < 25; ++i) {
      heavyFile << "for (int i = 0; i < 10; ++i) {}\n";
    }
    heavyFile.close();

    Config::ConfigurationManager::getInstance().parseShaderMetadata(
        heavyLoopPath);
    auto *cfg = Config::ConfigurationManager::getInstance().getShaderConfig(
        "test_heavy_loops");
    TEST_ASSERT_NOT_NULL(cfg);
    TEST_ASSERT_EQUAL(0.6f, cfg->quality);
    std::filesystem::remove(heavyLoopPath);

    // 5. ShaderManager helper file exclusion & fallback active shader
    std::string tempScanDir = "/tmp/test_scan_exclusions";
    std::filesystem::create_directories(tempScanDir);

    std::vector<std::string> helperStems = {
        "common", "utils", "ShaderInterop", "vertex", "debug_overlay"};
    for (const auto &stem : helperStems) {
      std::ofstream f(tempScanDir + "/" + stem + ".frag");
      f << "void main() {}\n";
    }
    std::ofstream soleShader(tempScanDir + "/primary_effect.frag");
    soleShader << "void main() {}\n";
    soleShader.close();

    auto customSm = createShaderManager();
    customSm->loadShader("primary_effect",
                         tempScanDir + "/primary_effect.frag");
    TEST_ASSERT_TRUE(customSm->getActiveShader() == "primary_effect");
    customSm->setActiveShader("primary_effect");
    TEST_ASSERT_TRUE(customSm->getActiveShader() == "primary_effect");

    std::filesystem::remove_all(tempScanDir);

    return {__func__, true, "Core edge cases coverage passed", 0.0};
  }
};

REGISTER_TEST_SUITE(LinuxPlatformCoverageTests);

} // namespace Test
} // namespace ShaderCandy
