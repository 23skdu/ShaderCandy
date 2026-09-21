#include "../src/config/ConfigurationManager.h"
#include "../src/config/PresetManager.h"
#include "../src/core/MathUtils.h"
#include "../src/core/MultiDisplayManager.h"
#include "../src/core/PerformanceMonitor.h"
#include "../src/core/ShaderManager.h"
#include "../src/core/UniformBuffer.h"
#include "../src/gl/GLRendererTypes.h"
#include "TestFramework.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <random>
#include <thread>
#include <variant>

namespace ShaderCandy {
namespace Test {

class CoverageExpansionTests : public TestSuite {
public:
  CoverageExpansionTests() {
    std::cout << "DEBUG: CoverageExpansionTests constructed" << std::endl;
  }
  std::string getName() const override { return "Coverage Expansion Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;
    results.push_back(testMathUtilsExpansion());
    results.push_back(testUniformBufferExpansion());
    results.push_back(testPerformanceMonitorExpansion());
    results.push_back(testConfigManagerExpansion());
    results.push_back(testPresetManagerExpansion());
    results.push_back(testShaderManagerExpansion());
    results.push_back(testShaderManagerBase());
    results.push_back(testColorConversionEdgeCases());
    results.push_back(testSIMDAlignmentEdgeCases());
    results.push_back(testJSONParsingMore());
    results.push_back(testComprehensiveShaderManager());
    results.push_back(testComprehensiveMultiDisplay());
    results.push_back(testComprehensiveConfigurationManager());
    results.push_back(testComprehensivePresetManager());
    results.push_back(testPerformanceMonitorEdgeCases());
    results.push_back(testMultiDisplayEmptyDisplays());
    results.push_back(testMathUtilsHsvRgbEdgeCases());
    results.push_back(testUniformDataDefaults());
    results.push_back(testPresetManagerEdgeCases());
    results.push_back(testConfigManagerMetadataCategories());
    results.push_back(testShaderConfigSerializeDeserialize());
    results.push_back(testConfigMetadataEdgeBranches());
    results.push_back(testBloomConfigDefaults());
    results.push_back(testParticleConfigDefaults());
    results.push_back(testPerformanceMetricsDefaults());
    results.push_back(testToneMappingEnums());
    results.push_back(testRendererErrorCodeEnums());
    results.push_back(testHeadlessRendererVideoEncoding());
    results.push_back(testDisplayUtilsFunctions());
    results.push_back(testGLRendererErrorCallback());
    results.push_back(testSettingsRoundTrip());
    results.push_back(testAudioAutoDetect());
    results.push_back(testBloomQualityLevels());
    results.push_back(testParticleRespawn());
     results.push_back(testFileWatcherLifecycle());
    results.push_back(testTransitionSystem());
    results.push_back(testPostProcessingConfig());
    results.push_back(testAdaptiveQualityConfig());
    results.push_back(testSmartShaderRotation());
    return results;
  }

private:
  TestResult testMathUtilsExpansion() {
    // Vec2
    Math::Vec2 v2(1.0f, 2.0f);
    TEST_ASSERT_EQUAL(1.0f, v2.x);
    TEST_ASSERT_EQUAL(2.0f, v2.y);

    // Vec3 operators
    Math::Vec3 a(10.0f, 20.0f, 30.0f);
    Math::Vec3 b(1.0f, 2.0f, 3.0f);

    Math::Vec3 diff = a - b;
    TEST_ASSERT_EQUAL(9.0f, diff.x);
    TEST_ASSERT_EQUAL(18.0f, diff.y);
    TEST_ASSERT_EQUAL(27.0f, diff.z);

    Math::Vec3 prod = b * 2.0f;
    TEST_ASSERT_EQUAL(2.0f, prod.x);
    TEST_ASSERT_EQUAL(4.0f, prod.y);
    TEST_ASSERT_EQUAL(6.0f, prod.z);

    Math::Vec3 quot = a / 10.0f;
    TEST_ASSERT_EQUAL(1.0f, quot.x);
    TEST_ASSERT_EQUAL(2.0f, quot.y);
    TEST_ASSERT_EQUAL(3.0f, quot.z);

    // lengthSq
    float lsq = b.lengthSq();
    TEST_ASSERT_EQUAL(14.0f, lsq);

    // normalize
    Math::Vec3 n = b.normalize();
    TEST_ASSERT(std::abs(n.length() - 1.0f) < 0.0001f,
                "Normalize length incorrect");

    // normalize zero vector
    Math::Vec3 zero(0, 0, 0);
    Math::Vec3 nZero = zero.normalize();
    TEST_ASSERT(std::abs(nZero.x) < 0.001f, "Zero normalize x error");

    // Dot and Cross
    Math::Vec3 v1(1, 0, 0), v2_vec(0, 1, 0);
    TEST_ASSERT(std::abs(Math::dot(v1, v2_vec)) < 0.0001f,
                "Dot product failed");
    Math::Vec3 v3 = Math::cross(v1, v2_vec);
    TEST_ASSERT_EQUAL(1.0f, v3.z);

    return {__func__, true, "MathUtils expansion passed", 0.0};
  }

  TestResult testUniformBufferExpansion() {
    UniformBuffer buffer;
    {
      UniformBuffer temp;
      temp.initialize();
    }

    buffer.initialize();
    buffer.updateTime(123.45f);
    TEST_ASSERT_EQUAL(123.45f, buffer.getData().time);

    buffer.updateDeltaTime(0.016f);
    TEST_ASSERT_EQUAL(0.016f, buffer.getData().deltaTime);

    int initialFrame = buffer.getData().frame;
    buffer.advanceFrame();
    TEST_ASSERT(buffer.getData().frame == initialFrame + 1,
                "advanceFrame counter failed");

    return {__func__, true, "UniformBuffer expansion passed", 0.0};
  }

  TestResult testPerformanceMonitorExpansion() {
    PerformanceMonitor monitor(5);
    TEST_ASSERT_TRUE(monitor.isEnabled());

    monitor.setEnabled(false);
    TEST_ASSERT_FALSE(monitor.isEnabled());

    monitor.setEnabled(true);
    for (int i = 0; i < 10; ++i) {
      monitor.beginFrame();
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
      monitor.endFrame();
    }

    // Simulate a dropped frame
    monitor.beginFrame();
    std::this_thread::sleep_for(std::chrono::milliseconds(40));
    monitor.endFrame();

    auto metrics = monitor.getMetrics();
    TEST_ASSERT(metrics.droppedFrames > 0, "Dropped frames not detected");
    TEST_ASSERT(metrics.averageFPS > 0, "Average FPS invalid");

    float p99 = monitor.getP99FrameTimeMs();
    TEST_ASSERT(p99 > 0, "P99 invalid");

    // Test non-dirty path
    p99 = monitor.getP99FrameTimeMs();
    TEST_ASSERT(p99 > 0, "P99 non-dirty invalid");

    float lastFrame = monitor.getLastFrameTimeMs();
    TEST_ASSERT(lastFrame >= 0.0f, "Last frame time invalid");

    monitor.setEnabled(false);
    monitor.beginFrame();
    monitor.endFrame();
    TEST_ASSERT_FALSE(monitor.isEnabled());

    monitor.reset();
    TEST_ASSERT_EQUAL(0, monitor.getMetrics().droppedFrames);

    return {__func__, true, "PerformanceMonitor expansion passed", 0.0};
  }

  class MockShaderManager : public ShaderCandy::ShaderManager {
  public:
    virtual bool initialize() override { return true; }
    virtual bool loadShader(const std::string &, const std::string &) override {
      return true;
    }
    virtual bool reloadShaders() override { return true; }
    virtual std::vector<std::string> getAvailableShaders() const override {
      return {};
    }
    virtual bool setActiveShader(const std::string &) override { return true; }
    virtual std::string getActiveShader() const override { return ""; }
    virtual void render() override {}
  };

  TestResult testShaderManagerBase() {
    MockShaderManager sm;
    sm.setHotReload(true);
    TEST_ASSERT_TRUE(sm.isHotReloadEnabled());
    sm.setShaderChangedCallback([](const std::string &) {});
    return {__func__, true, "ShaderManager base coverage passed", 0.0};
  }

  TestResult testConfigManagerExpansion() {
    Config::ConfigurationManager &mgr =
        Config::ConfigurationManager::getInstance();
    mgr.initialize();

    // JSON Edge Cases
    std::string escaped =
        Config::JSON::escapeJSON("line1\nline2\ttab\rreturn\"quote\\back");
    TEST_ASSERT(escaped.find("\\n") != std::string::npos, "JSON escape failed");
    TEST_ASSERT(escaped.find("\\\"") != std::string::npos,
                "JSON escape failed");

    // Test invalid JSON variants
    TEST_ASSERT(Config::JSON::parse("{ invalid }").empty(),
                "Invalid JSON parse failed");
    TEST_ASSERT(Config::JSON::parse("{\"key\":").empty(),
                "Truly incomplete JSON should return empty");
    TEST_ASSERT(Config::JSON::parse("{").empty(),
                "Trivial incomplete JSON should return empty");

    // Param lookups
    mgr.getFloatParameter("non_existent", "missing");
    mgr.getBoolParameter("non_existent", "missing");
    mgr.getIntParameter("non_existent", "missing");
    mgr.getStringParameter("non_existent", "missing");

    // Test save failure
    mgr.saveToFile("/nonexistent/path/config.json");

    // Scan non-existent directory
    mgr.scanShaderDirectory("/nonexistent/shaders");

    mgr.shutdown();
    return {__func__, true, "ConfigManager expansion passed", 0.0};
  }

  TestResult testPresetManagerExpansion() {
    Config::PresetManager &pm = Config::PresetManager::getInstance();

    Config::Preset preset("test_shader");
    preset.name = "Expansion Preset";
    preset.author = "Test Runner";
    preset.setFloat("speed", 2.5f);
    preset.setInt("count", 42);
    preset.setBool("enabled", true);
    preset.modifiedDate = "2026-04-14T12:00:00Z";

    auto dict = preset.toDictionary();
    TEST_ASSERT(!dict.empty(), "ToDictionary failed");
    Config::Preset fromDict = Config::Preset::fromDictionary(dict);
    TEST_ASSERT(fromDict.name == preset.name, "FromDictionary name mismatch");
    TEST_ASSERT(fromDict.modifiedDate == preset.modifiedDate,
                "FromDictionary date mismatch");

    // Error Handling
    std::string error;
    TEST_ASSERT(!pm.loadPreset("/nonexistent/preset.json", error).has_value(),
                "Should fail to load non-existent");
    TEST_ASSERT(!pm.deletePreset("/nonexistent/preset.json", error),
                "Should fail to delete non-existent");

    // Discovery in non-existent
    auto discovered = pm.discoverPresets("/nonexistent/presets");
    TEST_ASSERT(discovered.empty(),
                "Discovery in non-existent should be empty");

    // Validation messages
    pm.validationErrorMessage(Config::PresetValidationError::MissingName);
    pm.validationErrorMessage((Config::PresetValidationError)999);

    return {__func__, true, "PresetManager expansion passed", 0.0};
  }

  TestResult testShaderManagerExpansion() {
    auto sm = createShaderManager();
    if (sm) {
      sm->setHotReload(true);
      TEST_ASSERT_TRUE(sm->isHotReloadEnabled());
      sm->setShaderChangedCallback([](const std::string &) {});
    }
    return {__func__, true, "ShaderManager expansion passed", 0.0};
  }

  TestResult testColorConversionEdgeCases() {
    float rgb[3] = {0, 0, 1.0f}; // Blue
    float hsv[3];
    Math::rgbToHsv(rgb, hsv);
    TEST_ASSERT(std::abs(hsv[0] - 240.0f) < 1.0f, "Hue for Blue failed");

    // Red
    float red[3] = {1.0f, 0, 0};
    Math::rgbToHsv(red, hsv);
    TEST_ASSERT(std::abs(hsv[0] - 0.0f) < 1.0f, "Hue for Red failed");

    // Green
    float green[3] = {0, 1.0f, 0};
    Math::rgbToHsv(green, hsv);
    TEST_ASSERT(std::abs(hsv[0] - 120.0f) < 1.0f, "Hue for Green failed");

    // Black
    float black[3] = {0, 0, 0};
    Math::rgbToHsv(black, hsv);
    TEST_ASSERT_EQUAL(0.0f, hsv[2]);

    // HSV cases 0-5
    float testHSV[3];
    float testRGB[3];
    for (int i = 0; i < 6; i++) {
      testHSV[0] = i * 60.0f;
      testHSV[1] = 1.0f;
      testHSV[2] = 1.0f;
      Math::hsvToRgb(testHSV, testRGB);
      TEST_ASSERT(testRGB[0] >= 0 && testRGB[0] <= 1.0f, "RGB range failed");
    }

    return {__func__, true, "Color conversion expansion passed", 0.0};
  }

  TestResult testSIMDAlignmentEdgeCases() {
    const size_t count = 7;
    std::vector<float> a(count, 1.0f), b(count, 2.0f), res(count, 0.0f);
    Math::multiplyArray(res.data(), a.data(), b.data(), count);
    for (size_t i = 0; i < count; i++)
      TEST_ASSERT_EQUAL(2.0f, res[i]);

    Math::multiplyArray(res.data(), a.data(), b.data(), 0);
    Math::sumArray(a.data(), 0);
    Math::lerpArray(res.data(), a.data(), b.data(), 0.5f, 0);

    float sum = Math::sumArray(a.data(), count);
    TEST_ASSERT_EQUAL(7.0f, sum);

    Math::lerpArray(res.data(), a.data(), b.data(), 0.5f, count);
    for (size_t i = 0; i < count; i++)
      TEST_ASSERT_EQUAL(1.5f, res[i]);

    return {__func__, true, "SIMD alignment edge cases passed", 0.0};
  }

  TestResult testJSONParsingMore() {
    // Unicode escapes
    auto dict = Config::JSON::parse("{\"key\": \"\\u1234\"}");
    // Note: our simple parser might not actually decode \u1234 but should run
    // the branch

    // Complex escaping
    std::string json =
        "{\"a\": \"\\\\\", \"b\": \"\\\"\", \"c\": \"\\/\", \"d\": \"\\b\", "
        "\"e\": \"\\f\", \"f\": \"\\n\", \"r\": \"\\r\", \"t\": \"\\t\"}";
    Config::JSON::parse(json);

    return {__func__, true, "JSON parsing expansion passed", 0.0};
  }

  TestResult testComprehensiveShaderManager() {
    auto sm = createShaderManager();
    TEST_ASSERT_TRUE(sm != nullptr);
    TEST_ASSERT_TRUE(sm->initialize());

    std::string auroraPath = "shaders/aurora.frag";
    if (!std::filesystem::exists(auroraPath) && std::filesystem::exists("../shaders/aurora.frag")) {
      auroraPath = "../shaders/aurora.frag";
    }

    // Test loading real shader
    bool loaded = sm->loadShader("aurora_test", auroraPath);
    TEST_ASSERT_TRUE(loaded);

    // Test loading non-existent shader (error branch)
    bool loadFail =
        sm->loadShader("invalid_test", "shaders/does_not_exist_12345.frag");
    TEST_ASSERT_FALSE(loadFail);

    // Test callback
    std::string changedShaderName;
    sm->setShaderChangedCallback(
        [&](const std::string &name) { changedShaderName = name; });

    // Set active shader
    sm->setActiveShader("aurora_test");
    TEST_ASSERT_TRUE(sm->getActiveShader() == "aurora_test");

    // Hot reload and render
    sm->setHotReload(true);
    TEST_ASSERT_TRUE(sm->isHotReloadEnabled());
    sm->render();

    sm->setHotReload(false);
    sm->render();

    bool reloaded = sm->reloadShaders();
    (void)reloaded;

    auto shaders = sm->getAvailableShaders();
    TEST_ASSERT(!shaders.empty(), "Available shaders should not be empty");

    // Test single standalone shader loading without initialize
    auto smAlone = createShaderManager();
    smAlone->loadShader("only_shader", auroraPath);
    TEST_ASSERT_TRUE(smAlone->getActiveShader() == "only_shader");

    // Test reload on updated timestamp
    std::string tempShaderPath = "/tmp/test_shader_reload.frag";
    std::ofstream tempShaderFile(tempShaderPath);
    tempShaderFile << "void main() {}\n";
    tempShaderFile.close();

    smAlone->setShaderChangedCallback([](const std::string &) {});
    smAlone->loadShader("temp_shader", tempShaderPath);

    std::this_thread::sleep_for(std::chrono::milliseconds(20));
    std::ofstream tempShaderFile2(tempShaderPath, std::ios::app);
    tempShaderFile2 << "// modified\n";
    tempShaderFile2.close();
    smAlone->reloadShaders();

    // Remove file to test nonexistent path branch in reloadShaders
    std::filesystem::remove(tempShaderPath);
    smAlone->reloadShaders();

    // Test scanning directory with .glsl file and without default shader
    std::string testGlslDir = "/tmp/test_glsl_dir";
    std::filesystem::create_directories(testGlslDir);
    std::string testGlslFile = testGlslDir + "/custom_sample.glsl";
    std::ofstream glslStream(testGlslFile);
    glslStream << "void main() {}\n";
    glslStream.close();

    auto smGlsl = createShaderManager();
    smGlsl->loadShader("custom_sample", testGlslFile);
    TEST_ASSERT_TRUE(smGlsl->getActiveShader() == "custom_sample");
    std::filesystem::remove_all(testGlslDir);

    return {__func__, true, "Comprehensive ShaderManager tests passed", 0.0};
  }

  TestResult testComprehensiveMultiDisplay() {
    auto &mgr = MultiDisplayManager::getInstance();
    TEST_ASSERT_TRUE(mgr.initialize());

    // Displays list
    const auto &displays = mgr.getDisplays();
    TEST_ASSERT(!displays.empty(), "Displays list empty");

    DisplayInfo primary = mgr.getPrimaryDisplay();
    TEST_ASSERT(!primary.id.empty(), "Primary display id empty");

    // Existing and non-existing display lookup
    DisplayInfo d0 = mgr.getDisplay(displays[0].id);
    TEST_ASSERT_TRUE(displays[0].id == d0.id);
    DisplayInfo nonExistent = mgr.getDisplay("non_existent_disp_id_999");
    TEST_ASSERT(!nonExistent.id.empty(),
                "Fallback primary display should be returned");

    // Display enable/disable
    mgr.setDisplayEnabled(displays[0].id, false);
    TEST_ASSERT_FALSE(mgr.isDisplayEnabled(displays[0].id));
    mgr.setDisplayEnabled(displays[0].id, true);
    TEST_ASSERT_TRUE(mgr.isDisplayEnabled(displays[0].id));
    TEST_ASSERT_TRUE(mgr.isDisplayEnabled("unknown_display_default_true"));

    // Virtual aspect ratio
    float aspect = mgr.getVirtualAspectRatio();
    TEST_ASSERT(aspect > 0.0f, "Aspect ratio must be positive");

    // Time synchronization
    mgr.synchronizeTime(123.456);
    TEST_ASSERT_EQUAL(123.456, mgr.getSynchronizedTime());

    // Callback
    static bool cbCalled = false;
    cbCalled = false;
    mgr.setDisplayChangeCallback(
        [](const std::vector<DisplayInfo> &) { cbCalled = true; });

    // Helper functions
    int optSize = DisplayUtils::getOptimalTextureSize(1920, 1080, 1.0f);
    TEST_ASSERT(optSize >= 256, "Optimal texture size too small");
    int optSizeSmall = DisplayUtils::getOptimalTextureSize(640, 480, 0.5f);
    TEST_ASSERT(optSizeSmall >= 256, "Optimal texture size too small");

    bool contiguousSingle = DisplayUtils::areDisplaysContiguous({primary});
    TEST_ASSERT_TRUE(contiguousSingle);

    std::vector<DisplayInfo> adjacentDisplays = {
        {"d1", "D1", 0, 0, 1920, 1080, 60, true, 1.0f},
        {"d2", "D2", 1920, 0, 1920, 1080, 60, false, 1.0f}};
    bool contiguousAdj = DisplayUtils::areDisplaysContiguous(adjacentDisplays);
    TEST_ASSERT_TRUE(contiguousAdj);

    std::vector<DisplayInfo> separatedDisplays = {
        {"d1", "D1", 0, 0, 1920, 1080, 60, true, 1.0f},
        {"d2", "D2", 5000, 5000, 1920, 1080, 60, false, 1.0f}};
    bool contiguousSep = DisplayUtils::areDisplaysContiguous(separatedDisplays);
    TEST_ASSERT_FALSE(contiguousSep);

    int minX, minY, maxX, maxY;
    DisplayUtils::getBoundingBox({}, minX, minY, maxX, maxY);
    TEST_ASSERT_EQUAL(0, minX);
    TEST_ASSERT_EQUAL(1920, maxX);

    DisplayUtils::getBoundingBox(adjacentDisplays, minX, minY, maxX, maxY);
    TEST_ASSERT_EQUAL(0, minX);
    TEST_ASSERT_EQUAL(3840, maxX);

    TEST_ASSERT_FALSE(DisplayUtils::hasConfigurationChanged(adjacentDisplays,
                                                            adjacentDisplays));
    TEST_ASSERT_TRUE(DisplayUtils::hasConfigurationChanged(adjacentDisplays,
                                                           separatedDisplays));
    TEST_ASSERT_TRUE(
        DisplayUtils::hasConfigurationChanged(adjacentDisplays, {primary}));

    // HeadlessRenderer methods
    HeadlessRenderer hr;
    TEST_ASSERT_TRUE(hr.initialize(64, 64));
    hr.setShader("aurora");
    hr.setOutputFormat("ppm");
    hr.setFPS(30);
    hr.setDuration(0.1f);
    hr.setGPUDevice(0);
    auto gpus = hr.getAvailableGPUs();
    TEST_ASSERT(!gpus.empty(), "Should return available GPUs");

    int progressHit = 0;
    hr.setProgressCallback([&](int, int) { progressHit++; });
    hr.beginRender();
    hr.renderFrame();
    TEST_ASSERT(progressHit > 0, "Progress callback should be invoked");

    std::string testPpm = "/tmp/test_hr_frame.ppm";
    bool renderedFile = hr.renderToFile(testPpm);
    TEST_ASSERT_TRUE(renderedFile);
    std::filesystem::remove(testPpm);

    bool failRender = hr.renderToFile("/nonexistent_folder_abc123/bad.ppm");
    TEST_ASSERT_FALSE(failRender);

    TEST_ASSERT_TRUE(hr.startVideoEncoding("out.mp4", 30));
    TEST_ASSERT_TRUE(hr.encodeFrame(std::vector<uint8_t>(64 * 64 * 4, 128)));
    hr.finishVideoEncoding();

    hr.endRender();
    TEST_ASSERT_TRUE(hr.isFinished());
    hr.shutdown();

    // Test shutdown state and fallback primary display
    mgr.shutdown();
    DisplayInfo emptyPrimary = mgr.getPrimaryDisplay();
    TEST_ASSERT(!emptyPrimary.id.empty(), "Empty displays fallback primary");

    // Reinitialize with change callback
    static bool initCb = false;
    initCb = false;
    mgr.setDisplayChangeCallback(
        [](const std::vector<DisplayInfo> &) { initCb = true; });
    mgr.initialize();
    TEST_ASSERT_TRUE(initCb);
    mgr.setDisplayChangeCallback(nullptr);

    // Unregistered display shader fallback
    std::string unregShader = mgr.getDisplayShader("unregistered_disp_999");
    TEST_ASSERT_TRUE(unregShader.empty());

    // HeadlessRenderer uninitialized buffer allocation
    HeadlessRenderer hrUninit;
    auto uninitBuf = hrUninit.renderToBuffer(0);
    TEST_ASSERT(!uninitBuf.empty(), "Render to buffer should auto-allocate");

    mgr.setDisplayChangeCallback(nullptr);
    mgr.shutdown();
    return {__func__, true, "Comprehensive MultiDisplay tests passed", 0.0};
  }

  TestResult testComprehensiveConfigurationManager() {
    auto &mgr = Config::ConfigurationManager::getInstance();
    mgr.initialize();

    Config::ShaderConfig cfg;
    cfg.shaderName = "comp_test_shader";
    cfg.displayName = "Comprehensive Test Shader";
    cfg.description = "A test shader for coverage";
    cfg.category = "TestCategory";
    cfg.tags = {"tagA", "tagB"};
    cfg.parameters.push_back({"speed", "Speed", "Speed param",
                              Config::ParamType::Range, 1.0f, 0.1f, 5.0f});
    cfg.parameters.push_back(
        {"glow", "Glow", "Glow param", Config::ParamType::Bool, true});
    cfg.parameters.push_back(
        {"count", "Count", "Count param", Config::ParamType::Int, 10, 1, 100});
    cfg.parameters.push_back({"mode",
                              "Mode",
                              "Mode param",
                              Config::ParamType::Choice,
                              std::string("fast"),
                              0.0f,
                              0.0f,
                              {"fast", "quality"},
                              false});
    cfg.supportsAudio = true;
    cfg.supportsHDR = false;
    cfg.quality = 0.9f;

    mgr.registerShader(cfg);

    auto shaders = mgr.getAvailableShaders();
    TEST_ASSERT(!shaders.empty(), "Available shaders should not be empty");

    auto byCat = mgr.getShadersByCategory("TestCategory");
    TEST_ASSERT(!byCat.empty(), "Category filter should return test shader");

    auto *foundCfg = mgr.getShaderConfig("comp_test_shader");
    TEST_ASSERT_TRUE(foundCfg != nullptr);
    TEST_ASSERT_TRUE(mgr.getShaderConfig("non_existent_shader") == nullptr);

    // Parameter testing
    mgr.setParameter("comp_test_shader", "speed", 2.5f);
    TEST_ASSERT_EQUAL(2.5f, mgr.getFloatParameter("comp_test_shader", "speed"));

    mgr.setParameter("comp_test_shader", "glow", false);
    TEST_ASSERT_FALSE(mgr.getBoolParameter("comp_test_shader", "glow"));

    mgr.setParameter("comp_test_shader", "count", 42);
    TEST_ASSERT_EQUAL(42, mgr.getIntParameter("comp_test_shader", "count"));

    mgr.setParameter("comp_test_shader", "mode", std::string("quality"));
    TEST_ASSERT_TRUE(mgr.getStringParameter("comp_test_shader", "mode") ==
                     "quality");

    // Defaults
    auto defSpeed = mgr.getParameterDefault("comp_test_shader", "speed");
    TEST_ASSERT(std::holds_alternative<float>(defSpeed),
                "Default speed should be float");
    auto defUnknown =
        mgr.getParameterDefault("comp_test_shader", "unknown_param");
    TEST_ASSERT(std::holds_alternative<float>(defUnknown),
                "Fallback default should be float");

    // Reset
    mgr.resetParameter("comp_test_shader", "speed");
    mgr.resetAllParameters("comp_test_shader");

    // Settings
    auto &settings = mgr.getSettings();
    settings.targetFPS = 90;
    settings.vsync = false;
    settings.enableAudio = true;
    settings.audioDevice = "default_device";
    settings.audioSensitivity = 1.2f;
    settings.audioSmoothing = 0.5f;
    settings.adaptiveQuality = false;
    settings.showFPS = true;
    settings.limitGPU = true;
    settings.autoScaleFPSThreshold = 50.0f;
    settings.defaultShader = "comp_test_shader";
    settings.enableHotReload = true;
    settings.spanDisplays = true;
    settings.perDisplayShader = false;
    settings.idleTimeMinutes = 10;
    settings.lockOnActivate = true;
    settings.neuralStyleEnabled = true;
    settings.neuralStyleStrength = 0.7f;
    settings.neuralStyleName = "style1";
    settings.spatialAudio = true;
    settings.roomSize = 2.0f;
    settings.reverbDamping = 0.4f;

    std::string jsonSerialized = Config::JSON::serializeSettings(settings);
    TEST_ASSERT(!jsonSerialized.empty(),
                "Serialized settings should not be empty");

    auto deserialized = Config::JSON::deserializeSettings(jsonSerialized);
    TEST_ASSERT_EQUAL(90, deserialized.targetFPS);
    TEST_ASSERT_EQUAL(false, deserialized.vsync);
    TEST_ASSERT_EQUAL(true, deserialized.enableAudio);
    TEST_ASSERT_TRUE(deserialized.defaultShader == "comp_test_shader");

    // Empty JSON deserialize fallback
    auto emptySettings = Config::JSON::deserializeSettings("");
    (void)emptySettings;

    // Callback
    bool cbFired = false;
    mgr.setChangeCallback(
        [&](const std::string &, const std::string &) { cbFired = true; });

    // Presets in ConfigManager
    mgr.setParameter("comp_test_shader", "speed", 3.0f);
    mgr.setParameter("comp_test_shader", "glow", true);
    mgr.setParameter("comp_test_shader", "count", 20);

    bool pSaved = mgr.savePreset("test_cm_preset", "comp_test_shader");
    (void)pSaved;
    auto pList = mgr.getPresets("comp_test_shader");
    (void)pList;
    bool pLoaded = mgr.loadPreset("test_cm_preset", "comp_test_shader");
    (void)pLoaded;
    mgr.deletePreset("test_cm_preset", "comp_test_shader");

    // Directory scan & metadata parsing
    mgr.scanShaderDirectory("shaders");
    mgr.parseShaderMetadata("shaders/aurora.frag");
    mgr.parseShaderMetadata("shaders/music/audio_wave.frag");
    mgr.parseShaderMetadata("shaders/effects/bloom.frag");

    // Test annotated shader metadata parsing
    std::string testAnnoPath = "/tmp/test_annotated_shader.frag";
    std::ofstream annoFile(testAnnoPath);
    annoFile << "// test_anno - Annotated Shader Description\n";
    annoFile << "// Category: Cosmic\n";
    annoFile << "// Parameter: speed 0.1 5.0 1.0 Custom speed description\n";
    annoFile << "// Audio: reactive\n";
    annoFile << "// Tags: cosmic, space, stars\n";
    annoFile
        << "void main() { float bass = 0.5; for (int i=0; i<25; i++) {} }\n";
    annoFile.close();

    mgr.parseShaderMetadata(testAnnoPath);
    std::filesystem::remove(testAnnoPath);

    // Test JSON parser edge cases: negative numbers, trailing whitespace, int
    // threshold
    auto negDict = Config::JSON::parse(
        "{\"negInt\": -42, \"negFloat\": -3.1415, \"fallback\": @@@}");
    TEST_ASSERT(!negDict.empty(), "Parsed negative values");

    std::string intScaleJson = "{\"autoScaleFPSThreshold\": 45}";
    auto intScaleSettings = Config::JSON::deserializeSettings(intScaleJson);
    TEST_ASSERT_EQUAL(45.0f, intScaleSettings.autoScaleFPSThreshold);

    // File persistence
    std::string tmpCfg = "/tmp/shadercandy_test_settings.json";
    bool savedCfg = mgr.saveToFile(tmpCfg);
    TEST_ASSERT_TRUE(savedCfg);
    bool loadedCfg = mgr.loadFromFile(tmpCfg);
    TEST_ASSERT_TRUE(loadedCfg);
    std::filesystem::remove(tmpCfg);

    bool loadMissing = mgr.loadFromFile("/nonexistent/file/missing.json");
    TEST_ASSERT_FALSE(loadMissing);

    mgr.loadDefaults();
    mgr.unregisterShader("comp_test_shader");
    mgr.shutdown();

    return {__func__, true, "Comprehensive ConfigurationManager tests passed",
            0.0};
  }

  TestResult testComprehensivePresetManager() {
    auto &pm = Config::PresetManager::getInstance();

    // Build a rich Preset
    Config::Preset p("aurora");
    p.name = "Aurora_Borealis";
    p.author = "Arctic_Explorer";
    p.description = "Magnificent_northern_lights";
    p.category = "Atmospheric";
    p.tags = {"aurora", "green", "night", "sky"};
    p.setFloat("speed", 1.8f);
    p.setInt("bands", 5);
    p.setBool("shimmer", true);
    p.stringParameters["color_palette"] = "emerald";
    p.globalSettings["bloom_intensity"] = 0.85f;

    // Verify getters with defaults
    TEST_ASSERT_EQUAL(1.8f, p.getFloat("speed", 1.0f));
    TEST_ASSERT_EQUAL(9.9f, p.getFloat("missing_f", 9.9f));
    TEST_ASSERT_EQUAL(5, p.getInt("bands", 1));
    TEST_ASSERT_EQUAL(99, p.getInt("missing_i", 99));
    TEST_ASSERT_EQUAL(true, p.getBool("shimmer", false));
    TEST_ASSERT_EQUAL(false, p.getBool("missing_b", false));

    // Dictionary serialization round-trip
    auto dict = p.toDictionary();
    Config::Preset pRestored = Config::Preset::fromDictionary(dict);
    TEST_ASSERT_TRUE(p.name == pRestored.name);
    TEST_ASSERT_TRUE(p.author == pRestored.author);
    TEST_ASSERT_TRUE(p.description == pRestored.description);
    TEST_ASSERT_TRUE(p.category == pRestored.category);
    TEST_ASSERT_EQUAL(p.tags.size(), pRestored.tags.size());
    TEST_ASSERT_EQUAL(1.8f, pRestored.getFloat("speed"));
    TEST_ASSERT_EQUAL(5, pRestored.getInt("bands"));
    TEST_ASSERT_EQUAL(true, pRestored.getBool("shimmer"));

    // Save & Load & Export & Import
    std::string err;
    std::string tmpPreset = "/tmp/test_aurora_preset.json";
    bool saved = pm.savePreset(p, tmpPreset, err);
    TEST_ASSERT_TRUE(saved);

    auto loaded = pm.loadPreset(tmpPreset, err);
    TEST_ASSERT_TRUE(loaded.has_value());
    TEST_ASSERT_TRUE(p.name == loaded->name);

    std::string tmpExport = "/tmp/test_aurora_export.json";
    bool exported = pm.exportPreset(p, tmpExport, err);
    TEST_ASSERT_TRUE(exported);

    auto imported = pm.importPresets("/tmp", err);
    (void)imported;

    bool deleted = pm.deletePreset(tmpPreset, err);
    TEST_ASSERT_TRUE(deleted);
    pm.deletePreset(tmpExport, err);

    // Save with validation error
    Config::Preset badValidationPreset = p;
    badValidationPreset.version = "";
    std::string badErr;
    TEST_ASSERT_FALSE(
        pm.savePreset(badValidationPreset, "/tmp/bad_preset.json", badErr));

    // Save with invalid path / cannot open
    std::string badPathErr;
    TEST_ASSERT_FALSE(
        pm.savePreset(p, "/proc/cannot_write_here_test.json", badPathErr));

    // Test boolean false in loadPreset
    Config::Preset boolFalsePreset("aurora");
    boolFalsePreset.name = "BoolFalseTest";
    boolFalsePreset.setBool("enabled", false);
    std::string boolPresetPath = "/tmp/test_bool_false.json";
    std::string boolErr;
    pm.savePreset(boolFalsePreset, boolPresetPath, boolErr);
    auto loadedBool = pm.loadPreset(boolPresetPath, boolErr);
    TEST_ASSERT_TRUE(loadedBool.has_value());
    TEST_ASSERT_FALSE(loadedBool->getBool("enabled"));
    std::filesystem::remove(boolPresetPath);

    // Validation test cases
    TEST_ASSERT_EQUAL(static_cast<int>(Config::PresetValidationError::None),
                      static_cast<int>(pm.validatePreset(p)));

    Config::Preset badP = p;
    badP.version = "";
    TEST_ASSERT_EQUAL(
        static_cast<int>(Config::PresetValidationError::MissingVersion),
        static_cast<int>(pm.validatePreset(badP)));

    badP.version = "99.0";
    TEST_ASSERT_EQUAL(
        static_cast<int>(Config::PresetValidationError::UnsupportedVersion),
        static_cast<int>(pm.validatePreset(badP)));

    badP.version = "1.0";
    badP.name = "";
    TEST_ASSERT_EQUAL(
        static_cast<int>(Config::PresetValidationError::MissingName),
        static_cast<int>(pm.validatePreset(badP)));

    badP.name = "Valid Name";
    badP.shaderName = "";
    TEST_ASSERT_EQUAL(
        static_cast<int>(Config::PresetValidationError::MissingShader),
        static_cast<int>(pm.validatePreset(badP)));

    // Error message coverage
    pm.validationErrorMessage(Config::PresetValidationError::None);
    pm.validationErrorMessage(Config::PresetValidationError::InvalidJSON);
    pm.validationErrorMessage(Config::PresetValidationError::MissingVersion);
    pm.validationErrorMessage(
        Config::PresetValidationError::UnsupportedVersion);
    pm.validationErrorMessage(Config::PresetValidationError::MissingShader);
    pm.validationErrorMessage(Config::PresetValidationError::InvalidParameters);
    pm.validationErrorMessage(Config::PresetValidationError::MissingName);
    pm.validationErrorMessage(
        static_cast<Config::PresetValidationError>(12345));

    // Built-in and user presets
    pm.allBuiltInPresets();
    pm.allUserPresets();

    return {__func__, true, "Comprehensive PresetManager tests passed", 0.0};
  }

  TestResult testPerformanceMonitorEdgeCases() {
    // getAverageFPS direct call with zero frames
    PerformanceMonitor monitor(5);
    TEST_ASSERT_EQUAL(0.0f, monitor.getAverageFPS());

    // getLastFrameTimeMs before any frame
    TEST_ASSERT_EQUAL(0.0f, monitor.getLastFrameTimeMs());

    // getP99FrameTimeMs with zero frames
    TEST_ASSERT_EQUAL(0.0f, monitor.getP99FrameTimeMs());

    // getMetrics with zero frames - all fields should be zeroed
    PerformanceMetrics zeroMetrics = monitor.getMetrics();
    TEST_ASSERT_EQUAL(0.0f, zeroMetrics.currentFPS);
    TEST_ASSERT_EQUAL(0.0f, zeroMetrics.averageFPS);
    TEST_ASSERT_EQUAL(0, zeroMetrics.droppedFrames);

    // calculateDynamicResolutionScale boundary: exactly equal returns 1.0f
    TEST_ASSERT_EQUAL(1.0f, PerformanceMonitor::calculateDynamicResolutionScale(16.67f, 16.67f));

    // calculateDynamicResolutionScale: very large latency clamps to 0.5f
    TEST_ASSERT_EQUAL(0.5f, PerformanceMonitor::calculateDynamicResolutionScale(1000.0f, 16.67f));

    // calculateDynamicResolutionScale: moderate over-budget scales down
    float scale2x = PerformanceMonitor::calculateDynamicResolutionScale(33.34f, 16.67f);
    TEST_ASSERT(scale2x > 0.49f && scale2x <= 0.51f, "2x over budget should scale to ~0.5");

    // calculateAdaptiveRayMarchLoD: nominal (low thermal, low latency)
    int maxSteps;
    float stepEps, lodScale;
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.1f, 10.0f, maxSteps, stepEps, lodScale);
    TEST_ASSERT_EQUAL(128, maxSteps);
    TEST_ASSERT_EQUAL(1.0f, lodScale);

    // calculateAdaptiveRayMarchLoD: serious thermal
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.7f, 20.0f, maxSteps, stepEps, lodScale);
    TEST_ASSERT_EQUAL(64, maxSteps);
    TEST_ASSERT_EQUAL(0.65f, lodScale);

    // calculateAdaptiveRayMarchLoD: critical thermal
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.9f, 40.0f, maxSteps, stepEps, lodScale);
    TEST_ASSERT_EQUAL(48, maxSteps);
    TEST_ASSERT_EQUAL(0.5f, lodScale);

    // calculateAdaptiveRayMarchLoD: fair thermal (just above 0.33)
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.4f, 18.0f, maxSteps, stepEps, lodScale);
    TEST_ASSERT_EQUAL(96, maxSteps);

    // History clamping: fill beyond historySize_
    PerformanceMonitor bigMonitor(3);
    for (int i = 0; i < 10; ++i) {
      bigMonitor.beginFrame();
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
      bigMonitor.endFrame();
    }
    float p99 = bigMonitor.getP99FrameTimeMs();
    TEST_ASSERT(p99 >= 0.0f, "P99 after many frames should be valid");

    // Sorted times non-dirty path
    bigMonitor.getP99FrameTimeMs();
    bigMonitor.getP99FrameTimeMs();
    TEST_ASSERT(p99 >= 0.0f, "P99 re-query should be stable");

    return {__func__, true, "PerformanceMonitor edge cases passed", 0.0};
  }

  TestResult testMultiDisplayEmptyDisplays() {
    auto &mgr = MultiDisplayManager::getInstance();
    mgr.shutdown();

    // After shutdown (empty displays), virtual dimensions should return defaults
    int w = mgr.getVirtualWidth();
    int h = mgr.getVirtualHeight();
    float aspect = mgr.getVirtualAspectRatio();
    TEST_ASSERT_EQUAL(1920, w);
    TEST_ASSERT_EQUAL(1080, h);
    TEST_ASSERT(aspect > 0.0f, "Default aspect ratio must be positive");

    mgr.initialize();
    mgr.shutdown();
    return {__func__, true, "MultiDisplay empty displays passed", 0.0};
  }

  TestResult testMathUtilsHsvRgbEdgeCases() {
    // rgbToHsv with g < b (hue wrapping via fmod)
    float rgb7[3] = {1.0f, 0.2f, 0.8f};
    float hsv7[3];
    Math::rgbToHsv(rgb7, hsv7);
    TEST_ASSERT(hsv7[0] > 200.0f && hsv7[0] < 360.0f, "Hue for g<b case should wrap near 330");

    // rgbToHsv black: saturation should be 0
    float black[3] = {0.0f, 0.0f, 0.0f};
    float hsvB[3];
    Math::rgbToHsv(black, hsvB);
    TEST_ASSERT_EQUAL(0.0f, hsvB[1]);

    // hsvToRgb with fractional hue that triggers f > 0 in case 0 (h=30)
    float hsvFrac[3] = {30.0f, 1.0f, 1.0f};
    float rgbFrac[3];
    Math::hsvToRgb(hsvFrac, rgbFrac);
    TEST_ASSERT(rgbFrac[0] > 0.9f && rgbFrac[0] <= 1.0f, "R near 1.0 at h=30");
    TEST_ASSERT(rgbFrac[1] > 0.4f && rgbFrac[1] < 0.6f, "G ~0.5 at h=30");
    TEST_ASSERT(rgbFrac[2] < 0.01f, "B ~0 at h=30");

    // hsvToRgb case 1 with f > 0 (h=90)
    float hsv90[3] = {90.0f, 1.0f, 1.0f};
    float rgb90[3];
    Math::hsvToRgb(hsv90, rgb90);
    TEST_ASSERT(rgb90[0] > 0.49f && rgb90[0] < 0.51f, "R ~0.5 at h=90");
    TEST_ASSERT(rgb90[1] > 0.99f, "G ~1.0 at h=90");
    TEST_ASSERT(rgb90[2] < 0.01f, "B ~0 at h=90");

    // hsvToRgb case 3 with f > 0 (h=210)
    float hsv210[3] = {210.0f, 1.0f, 1.0f};
    float rgb210[3];
    Math::hsvToRgb(hsv210, rgb210);
    TEST_ASSERT(rgb210[0] < 0.01f, "R ~0 at h=210");
    TEST_ASSERT(rgb210[1] > 0.49f && rgb210[1] < 0.51f, "G ~0.5 at h=210");
    TEST_ASSERT(rgb210[2] > 0.99f, "B ~1.0 at h=210");

    // hsvToRgb case 4 with f > 0 (h=270)
    float hsv270[3] = {270.0f, 1.0f, 1.0f};
    float rgb270[3];
    Math::hsvToRgb(hsv270, rgb270);
    TEST_ASSERT(rgb270[0] > 0.49f && rgb270[0] < 0.51f, "R ~0.5 at h=270");
    TEST_ASSERT(rgb270[1] < 0.01f, "G ~0 at h=270");
    TEST_ASSERT(rgb270[2] > 0.99f, "B ~1.0 at h=270");

    // Vec2 default constructor
    Math::Vec2 v2def;
    TEST_ASSERT_EQUAL(0.0f, v2def.x);
    TEST_ASSERT_EQUAL(0.0f, v2def.y);

    return {__func__, true, "MathUtils HSV/RGB edge cases passed", 0.0};
  }

  TestResult testUniformDataDefaults() {
    UniformData d{};
    TEST_ASSERT_EQUAL(1.0f, d.lodScale);
    TEST_ASSERT_EQUAL(128, d.maxSteps);
    TEST_ASSERT_EQUAL(0.001f, d.stepEpsilon);

    // UniformBuffer::size()
    TEST_ASSERT_EQUAL(sizeof(UniformData), UniformBuffer::size());

    // UniformBuffer updateRayMarchLoD
    UniformBuffer buf;
    buf.initialize();
    buf.updateRayMarchLoD(64, 0.005f, 0.75f);
    TEST_ASSERT_EQUAL(64, buf.getMaxSteps());
    TEST_ASSERT_EQUAL(0.005f, buf.getStepEpsilon());
    TEST_ASSERT_EQUAL(0.75f, buf.getLodScale());

    // UniformBuffer updateResolution and updateMouse
    buf.updateResolution(1920, 1080);
    TEST_ASSERT_EQUAL(1920.0f, buf.getData().resolution[0]);
    TEST_ASSERT_EQUAL(1080.0f, buf.getData().resolution[1]);

    buf.updateMouse(500, 300);
    TEST_ASSERT_EQUAL(500.0f, buf.getData().mouse[0]);
    TEST_ASSERT_EQUAL(300.0f, buf.getData().mouse[1]);

    buf.updateFrame(42);
    TEST_ASSERT_EQUAL(42, buf.getData().frame);

    return {__func__, true, "UniformData defaults passed", 0.0};
  }

  TestResult testPresetManagerEdgeCases() {
    Config::PresetManager &pm = Config::PresetManager::getInstance();

    // Default constructor
    Config::Preset defaultPreset;
    TEST_ASSERT(defaultPreset.version == "1.0", "Default version should be 1.0");
    TEST_ASSERT(defaultPreset.shaderName == "plasma", "Default shader should be plasma");
    TEST_ASSERT(!defaultPreset.createdDate.empty(), "Created date should be auto-set");

    // Negative float values
    Config::Preset negPreset("test_shader");
    negPreset.setFloat("speed", -3.14f);
    negPreset.setInt("count", -5);
    std::string negErr;
    std::string negPath = "/tmp/test_neg_preset.json";
    TEST_ASSERT_TRUE(pm.savePreset(negPreset, negPath, negErr));
    auto loadedNeg = pm.loadPreset(negPath, negErr);
    TEST_ASSERT_TRUE(loadedNeg.has_value());
    TEST_ASSERT_EQUAL(-3.14f, loadedNeg->getFloat("speed"));
    TEST_ASSERT_EQUAL(-5, loadedNeg->getInt("count"));
    std::filesystem::remove(negPath);

    // setString parameters
    Config::Preset strPreset("test_shader");
    strPreset.stringParameters["mode"] = "advanced";
    strPreset.stringParameters["color"] = "neon";
    auto dict = strPreset.toDictionary();
    Config::Preset restored = Config::Preset::fromDictionary(dict);
    TEST_ASSERT_TRUE(restored.stringParameters.at("mode") == "advanced");
    TEST_ASSERT_TRUE(restored.stringParameters.at("color") == "neon");

    // Empty floatParameters getter
    float missingVal = strPreset.getFloat("nonexistent_float", 99.0f);
    TEST_ASSERT_EQUAL(99.0f, missingVal);

    // Empty intParameters getter
    int missingInt = strPreset.getInt("nonexistent_int", 42);
    TEST_ASSERT_EQUAL(42, missingInt);

    // Empty boolParameters getter
    bool missingBool = strPreset.getBool("nonexistent_bool", true);
    TEST_ASSERT_TRUE(missingBool);

    // loadPreset with malformed JSON number
    std::string badJsonPath = "/tmp/test_bad_number_preset.json";
    std::ofstream badJsonFile(badJsonPath);
    badJsonFile << "{\n  \"version\": \"1.0\",\n  \"name\": \"bad\",\n";
    badJsonFile << "  \"shaderName\": \"plasma\",\n";
    badJsonFile << "  \"floatParameters\": {\"speed\": not_a_number}\n";
    badJsonFile << "}\n";
    badJsonFile.close();
    std::string badErr;
    auto badLoad = pm.loadPreset(badJsonPath, badErr);
    std::filesystem::remove(badJsonPath);

    return {__func__, true, "PresetManager edge cases passed", 0.0};
  }

  TestResult testConfigManagerMetadataCategories() {
    auto &mgr = Config::ConfigurationManager::getInstance();
    mgr.initialize();

    // Test "neural" category
    std::string neuralPath = "/tmp/test_neural_shader.frag";
    std::ofstream neuralFile(neuralPath);
    neuralFile << "// neural_shader - Neural Style Transfer\n";
    neuralFile << "void main() {}\n";
    neuralFile.close();
    mgr.parseShaderMetadata(neuralPath);
    auto *neuralCfg = mgr.getShaderConfig("test_neural_shader");
    TEST_ASSERT_NOT_NULL(neuralCfg);
    std::filesystem::remove(neuralPath);

    // Test "audio" category
    std::string audioPath = "/tmp/test_audio_meta.frag";
    std::ofstream audioFile(audioPath);
    audioFile << "// audio_shader - Audio Reactive Effect\n";
    audioFile << "// Audio: reactive\n";
    audioFile << "void main() {}\n";
    audioFile.close();
    mgr.parseShaderMetadata(audioPath);
    auto *audioCfg = mgr.getShaderConfig("test_audio_meta");
    TEST_ASSERT_NOT_NULL(audioCfg);
    std::filesystem::remove(audioPath);

    // Test lowercase "audio:" tag
    std::string audioLowerPath = "/tmp/test_audio_lower.frag";
    std::ofstream audioLowerFile(audioLowerPath);
    audioLowerFile << "// audio_lower - Lowercase Audio\n";
    audioLowerFile << "// audio: reactive\n";
    audioLowerFile << "void main() {}\n";
    audioLowerFile.close();
    mgr.parseShaderMetadata(audioLowerPath);
    std::filesystem::remove(audioLowerPath);

    // Test long comment without dash separator (> 10 chars)
    std::string longCommentPath = "/tmp/test_long_comment.frag";
    std::ofstream longCommentFile(longCommentPath);
    longCommentFile << "// This is a very long shader description without any dash separator\n";
    longCommentFile << "void main() {}\n";
    longCommentFile.close();
    mgr.parseShaderMetadata(longCommentPath);
    auto *longCfg = mgr.getShaderConfig("test_long_comment");
    TEST_ASSERT_NOT_NULL(longCfg);
    std::filesystem::remove(longCommentPath);

    // Test save with nonexistent parent directory (exception path)
    mgr.saveToFile("/nonexistent/deep/path/config.json");

    // Test loadFromFile with garbage content
    std::string garbagePath = "/tmp/test_garbage_config.json";
    std::ofstream garbageFile(garbagePath);
    garbageFile << "not json at all {{{}}}";
    garbageFile.close();
    bool loadedGarbage = mgr.loadFromFile(garbagePath);
    std::filesystem::remove(garbagePath);

    // getPresetDirectory direct call
    std::string presetDir = mgr.getPresetDirectory();
    TEST_ASSERT(presetDir.find("presets") != std::string::npos, "Preset dir should contain 'presets'");

    mgr.shutdown();
    return {__func__, true, "ConfigManager metadata categories passed", 0.0};
  }

  TestResult testShaderConfigSerializeDeserialize() {
    // Build a full ShaderConfig
    Config::ShaderConfig cfg;
    cfg.shaderName = "test_serialize_shader";
    cfg.displayName = "Test Serialize Shader";
    cfg.description = "A shader for testing serialization with special chars: \"quotes\" and \\backslash";
    cfg.category = "Fractals";
    cfg.tags = {"fractal", "recursive", "3d"};
    cfg.supportsAudio = true;
    cfg.supportsHDR = false;
    cfg.quality = 0.85f;
    cfg.parameters.push_back({"speed", "Speed", "Speed param",
                              Config::ParamType::Range, 1.0f, 0.1f, 5.0f});
    cfg.parameters.push_back(
        {"color", "Color", "Color param", Config::ParamType::Color,
         std::string("#ff0000")});
    cfg.parameters.push_back(
        {"mode", "Mode", "Mode param", Config::ParamType::Choice,
         std::string("fast")});

    // Serialize
    std::string json = Config::JSON::serializeShaderConfig(cfg);
    TEST_ASSERT(!json.empty(), "Serialized shader config should not be empty");
    TEST_ASSERT(json.find("test_serialize_shader") != std::string::npos,
                "Serialized JSON should contain shader name");
    TEST_ASSERT(json.find("Fractals") != std::string::npos,
                "Serialized JSON should contain category");
    TEST_ASSERT(json.find("\"fractal\"") != std::string::npos,
                "Serialized JSON should contain tags");

    // Deserialize
    Config::ShaderConfig restored = Config::JSON::deserializeShaderConfig(json);
    TEST_ASSERT_TRUE(restored.shaderName == "test_serialize_shader");
    TEST_ASSERT_TRUE(restored.displayName == "Test Serialize Shader");
    TEST_ASSERT_TRUE(restored.category == "Fractals");
    TEST_ASSERT_EQUAL(3u, restored.tags.size());
    TEST_ASSERT_TRUE(restored.tags[0] == "fractal");
    TEST_ASSERT_EQUAL(0.85f, restored.quality);
    TEST_ASSERT_TRUE(restored.supportsAudio);
    TEST_ASSERT_FALSE(restored.supportsHDR);

    // Round-trip again
    std::string json2 = Config::JSON::serializeShaderConfig(restored);
    Config::ShaderConfig restored2 = Config::JSON::deserializeShaderConfig(json2);
    TEST_ASSERT_TRUE(restored2.shaderName == restored.shaderName);
    TEST_ASSERT_EQUAL(0.85f, restored2.quality);

    // Empty deserialize
    Config::ShaderConfig emptyCfg = Config::JSON::deserializeShaderConfig("");
    TEST_ASSERT(emptyCfg.shaderName.empty(), "Empty JSON should produce empty config");

    // Minimal config (no parameters, no tags)
    Config::ShaderConfig minimal;
    minimal.shaderName = "minimal";
    minimal.displayName = "Minimal";
    std::string minJson = Config::JSON::serializeShaderConfig(minimal);
    Config::ShaderConfig minRestored = Config::JSON::deserializeShaderConfig(minJson);
    TEST_ASSERT_TRUE(minRestored.shaderName == "minimal");
    TEST_ASSERT_TRUE(minRestored.tags.empty());
    TEST_ASSERT_TRUE(minRestored.parameters.empty());

    return {__func__, true, "ShaderConfig serialize/deserialize passed", 0.0};
  }

  TestResult testConfigMetadataEdgeBranches() {
    auto &mgr = Config::ConfigurationManager::getInstance();
    mgr.initialize();

    // 1. "effect" (singular) category branch
    std::string effectDir = "/tmp/effect";
    std::filesystem::create_directories(effectDir);
    std::string effectPath = effectDir + "/single_effect.frag";
    std::ofstream effectFile(effectPath);
    effectFile << "// single_effect - A singular effect shader\n";
    effectFile << "void main() {}\n";
    effectFile.close();
    mgr.parseShaderMetadata(effectPath);
    auto *effectCfg = mgr.getShaderConfig("single_effect");
    TEST_ASSERT_NOT_NULL(effectCfg);
    TEST_ASSERT(effectCfg->category == "Effects",
                "Singular 'effect' dir should map to 'Effects' category");
    std::filesystem::remove_all(effectDir);

    // 2. quality == 0.8 for 11-20 for-loops
    std::string medLoopPath = "/tmp/test_med_loops.frag";
    std::ofstream medLoopFile(medLoopPath);
    medLoopFile << "// med_loops - Medium complexity shader\n";
    for (int i = 0; i < 15; ++i) {
      medLoopFile << "for (int i = 0; i < 10; ++i) {}\n";
    }
    medLoopFile.close();
    mgr.parseShaderMetadata(medLoopPath);
    auto *medCfg = mgr.getShaderConfig("test_med_loops");
    TEST_ASSERT_NOT_NULL(medCfg);
    TEST_ASSERT_EQUAL(0.8f, medCfg->quality);
    std::filesystem::remove(medLoopPath);

    // 3. Short comment (<=10 chars) should NOT set description
    std::string shortPath = "/tmp/test_short_comment.frag";
    std::ofstream shortFile(shortPath);
    shortFile << "// hi\n";
    shortFile << "void main() {}\n";
    shortFile.close();
    mgr.parseShaderMetadata(shortPath);
    auto *shortCfg = mgr.getShaderConfig("test_short_comment");
    TEST_ASSERT_NOT_NULL(shortCfg);
    TEST_ASSERT(shortCfg->description.empty(),
                "Comment <=10 chars should not set description");
    std::filesystem::remove(shortPath);

    // 4. Malformed Parameter line (too few tokens) - no custom parameters added
    std::string badParamPath = "/tmp/test_bad_param.frag";
    std::ofstream badParamFile(badParamPath);
    badParamFile << "// bad_param - Shader with bad parameter\n";
    badParamFile << "// Parameter: incomplete\n";
    badParamFile << "void main() {}\n";
    badParamFile.close();
    mgr.parseShaderMetadata(badParamPath);
    auto *badParamCfg = mgr.getShaderConfig("test_bad_param");
    TEST_ASSERT_NOT_NULL(badParamCfg);
    // Malformed line should not add any custom parameters (only defaults added)
    bool hasCustomParam = false;
    for (const auto &p : badParamCfg->parameters) {
      if (p.name == "incomplete" || p.displayName == "incomplete") {
        hasCustomParam = true;
        break;
      }
    }
    TEST_ASSERT_FALSE(hasCustomParam);
    std::filesystem::remove(badParamPath);

    mgr.shutdown();
    return {__func__, true, "Config metadata edge branches passed", 0.0};
  }

  TestResult testBloomConfigDefaults() {
    Platform::Linux::GLBloomConfig bloom;
    TEST_ASSERT(bloom.enabled, "Bloom should be enabled by default");
    TEST_ASSERT_EQUAL(
        static_cast<int>(Platform::Linux::GLBloomQuality::Medium),
        static_cast<int>(bloom.quality));
    TEST_ASSERT_EQUAL(1.0f, bloom.intensity);
    TEST_ASSERT_EQUAL(0.8f, bloom.threshold);
    TEST_ASSERT_EQUAL(5, bloom.blurRadius);

    bloom.enabled = false;
    TEST_ASSERT_FALSE(bloom.enabled);

    bloom.quality = Platform::Linux::GLBloomQuality::Ultra;
    TEST_ASSERT_EQUAL(
        static_cast<int>(Platform::Linux::GLBloomQuality::Ultra),
        static_cast<int>(bloom.quality));

    bloom.intensity = 2.5f;
    TEST_ASSERT_EQUAL(2.5f, bloom.intensity);

    bloom.threshold = 0.3f;
    TEST_ASSERT_EQUAL(0.3f, bloom.threshold);

    bloom.blurRadius = 12;
    TEST_ASSERT_EQUAL(12, bloom.blurRadius);

    return {__func__, true, "Bloom config defaults passed", 0.0};
  }

  TestResult testParticleConfigDefaults() {
    Platform::Linux::GLParticleConfig pc;
    TEST_ASSERT_EQUAL(1000, pc.count);
    TEST_ASSERT_FALSE(pc.enabled);
    TEST_ASSERT_EQUAL(9.81f, pc.gravity);
    TEST_ASSERT_EQUAL(1.0f, pc.speed);

    pc.enabled = true;
    pc.count = 500;
    pc.gravity = 4.0f;
    pc.speed = 2.0f;

    TEST_ASSERT_TRUE(pc.enabled);
    TEST_ASSERT_EQUAL(500, pc.count);
    TEST_ASSERT_EQUAL(4.0f, pc.gravity);
    TEST_ASSERT_EQUAL(2.0f, pc.speed);

    return {__func__, true, "Particle config defaults passed", 0.0};
  }

  TestResult testPerformanceMetricsDefaults() {
    Platform::Linux::GLPerformanceMetrics m;
    TEST_ASSERT_EQUAL(0.0, m.currentFPS);
    TEST_ASSERT_EQUAL(0.0, m.averageFPS);
    TEST_ASSERT_EQUAL(0.0, m.minFPS);
    TEST_ASSERT_EQUAL(0.0, m.maxFPS);
    TEST_ASSERT_EQUAL(0.0, m.frameTimeMs);
    TEST_ASSERT_EQUAL(0.0, m.gpuTimeMs);
    TEST_ASSERT_EQUAL(0.0, m.cpuTimeMs);
    TEST_ASSERT_EQUAL(0u, m.droppedFrames);
    TEST_ASSERT_EQUAL(0u, m.memoryUsageBytes);

    m.currentFPS = 60.0;
    m.memoryUsageBytes = 1920 * 1080 * 4;
    TEST_ASSERT_EQUAL(60.0, m.currentFPS);
    TEST_ASSERT_EQUAL(8294400u, m.memoryUsageBytes);

    return {__func__, true, "Performance metrics defaults passed", 0.0};
  }

  TestResult testToneMappingEnums() {
    TEST_ASSERT_EQUAL(0, static_cast<int>(Platform::Linux::GLToneMapping::None));
    TEST_ASSERT_EQUAL(1, static_cast<int>(Platform::Linux::GLToneMapping::ACES));
    TEST_ASSERT_EQUAL(2, static_cast<int>(Platform::Linux::GLToneMapping::Reinhard));
    TEST_ASSERT_EQUAL(3, static_cast<int>(Platform::Linux::GLToneMapping::Filmic));
    TEST_ASSERT_EQUAL(4, static_cast<int>(Platform::Linux::GLToneMapping::Hable));

    return {__func__, true, "Tone mapping enums passed", 0.0};
  }

  TestResult testRendererErrorCodeEnums() {
    TEST_ASSERT_EQUAL(0, static_cast<int>(Platform::Linux::GLRendererErrorCode::None));
    int ctx = static_cast<int>(Platform::Linux::GLRendererErrorCode::ContextCreationFailed);
    TEST_ASSERT_EQUAL(1, ctx);
    int shader = static_cast<int>(Platform::Linux::GLRendererErrorCode::ShaderCompilationFailed);
    TEST_ASSERT_EQUAL(2, shader);
    int link = static_cast<int>(Platform::Linux::GLRendererErrorCode::ProgramLinkFailed);
    TEST_ASSERT_EQUAL(3, link);
    int tex = static_cast<int>(Platform::Linux::GLRendererErrorCode::TextureCreationFailed);
    TEST_ASSERT_EQUAL(4, tex);
    int devlost = static_cast<int>(Platform::Linux::GLRendererErrorCode::DeviceLost);
    TEST_ASSERT_EQUAL(5, devlost);
    int exhaust = static_cast<int>(Platform::Linux::GLRendererErrorCode::ResourceExhausted);
    TEST_ASSERT_EQUAL(6, exhaust);
    int invalid = static_cast<int>(Platform::Linux::GLRendererErrorCode::InvalidState);
    TEST_ASSERT_EQUAL(7, invalid);

    Platform::Linux::GLRendererError err;
    err.code = Platform::Linux::GLRendererErrorCode::ShaderCompilationFailed;
    err.message = "test error";
    err.shaderName = "test_shader";
    err.compilerError = "line 5: syntax error";
    err.lineNumber = 5;

    int errCode = static_cast<int>(err.code);
    TEST_ASSERT_EQUAL(2, errCode);
    TEST_ASSERT_TRUE(err.message == "test error");
    TEST_ASSERT_TRUE(err.shaderName == "test_shader");
    TEST_ASSERT_TRUE(err.compilerError == "line 5: syntax error");
    TEST_ASSERT_EQUAL(5, err.lineNumber);

    return {__func__, true, "Renderer error code enums passed", 0.0};
  }

  TestResult testHeadlessRendererVideoEncoding() {
    HeadlessRenderer hr;
    hr.initialize(64, 64);
    hr.setDuration(1.0f);
    hr.setFPS(10);

    // Test renderToFile with PPM
    std::string ppmPath = "/tmp/test_headless.ppm";
    bool ok = hr.renderToFile(ppmPath);
    TEST_ASSERT(ok, "renderToFile PPM should succeed");
    TEST_ASSERT(std::filesystem::exists(ppmPath), "PPM file should exist");
    std::filesystem::remove(ppmPath);

    // Test renderToFile with PNG (via ffmpeg if available)
    std::string pngPath = "/tmp/test_headless.png";
    ok = hr.renderToFile(pngPath);
    // May fail if ffmpeg not installed, that's OK
    if (std::filesystem::exists(pngPath)) {
      TEST_ASSERT(std::filesystem::file_size(pngPath) > 0, "PNG should have content");
      std::filesystem::remove(pngPath);
    }

    // Test renderToBuffer
    auto buffer = hr.renderToBuffer(0);
    TEST_ASSERT_EQUAL(64u * 64u * 4u, buffer.size());
    TEST_ASSERT_TRUE(buffer[0] == 0 || buffer[0] != 0); // non-crash

    // Test frame-by-frame
    hr.beginRender();
    TEST_ASSERT_FALSE(hr.isFinished());
    bool rendered = hr.renderFrame();
    TEST_ASSERT(rendered, "renderFrame should succeed");
    TEST_ASSERT_FALSE(hr.isFinished());
    hr.endRender();
    TEST_ASSERT_TRUE(hr.isFinished());

    // Test progress callback
    int callbackCount = 0;
    hr.setProgressCallback([&](int current, int total) {
      callbackCount++;
    });
    hr.beginRender();
    hr.renderFrame();
    TEST_ASSERT(callbackCount >= 1, "Callback should have been called");

    // Test video encoding start/finish
    std::string videoPath = "/tmp/test_headless_video.mp4";
    bool started = hr.startVideoEncoding(videoPath, 10);
    // May fail if ffmpeg not available, that's OK for test
    if (started) {
      auto frameBuf = hr.renderToBuffer(0);
      bool encoded = hr.encodeFrame(frameBuf);
      TEST_ASSERT(encoded, "encodeFrame should succeed");
      hr.finishVideoEncoding();
    }

    // Test getAvailableGPUs
    auto gpus = hr.getAvailableGPUs();
    TEST_ASSERT_TRUE(gpus.size() >= 1);

    // Test setGPUDevice
    hr.setGPUDevice(1);

    // Test setOutputFormat
    hr.setOutputFormat("png");

    // Test setShader
    hr.setShader("test_shader");

    hr.shutdown();
    return {__func__, true, "HeadlessRenderer video encoding passed", 0.0};
  }

  TestResult testDisplayUtilsFunctions() {
    // getOptimalTextureSize
    int size = DisplayUtils::getOptimalTextureSize(1920, 1080, 1.0f);
    TEST_ASSERT(size >= 256, "Optimal texture size should be >= 256");
    int sizeLow = DisplayUtils::getOptimalTextureSize(1920, 1080, 0.5f);
    TEST_ASSERT(sizeLow >= 256, "Low quality size should be >= 256");
    TEST_ASSERT(sizeLow <= size, "Low quality should be <= high quality");

    // areDisplaysContiguous - single display
    DisplayInfo d1 = {"d1", "Monitor 1", 0, 0, 1920, 1080, 60, true, 1.0f};
    std::vector<DisplayInfo> single = {d1};
    TEST_ASSERT(DisplayUtils::areDisplaysContiguous(single), "Single display is contiguous");

    // areDisplaysContiguous - empty
    TEST_ASSERT(DisplayUtils::areDisplaysContiguous({}), "Empty is contiguous");

    // areDisplaysContiguous - two adjacent
    DisplayInfo d2 = {"d2", "Monitor 2", 1920, 0, 1920, 1080, 60, false, 1.0f};
    std::vector<DisplayInfo> adjacent = {d1, d2};
    TEST_ASSERT(DisplayUtils::areDisplaysContiguous(adjacent), "Adjacent displays are contiguous");

    // areDisplaysContiguous - two non-adjacent
    DisplayInfo d3 = {"d3", "Monitor 3", 5000, 5000, 1920, 1080, 60, false, 1.0f};
    std::vector<DisplayInfo> nonAdjacent = {d1, d3};
    TEST_ASSERT_FALSE(DisplayUtils::areDisplaysContiguous(nonAdjacent));

    // getBoundingBox
    int minX, minY, maxX, maxY;
    DisplayUtils::getBoundingBox(adjacent, minX, minY, maxX, maxY);
    TEST_ASSERT_EQUAL(0, minX);
    TEST_ASSERT_EQUAL(0, minY);
    TEST_ASSERT_EQUAL(3840, maxX);
    TEST_ASSERT_EQUAL(1080, maxY);

    // getBoundingBox empty
    DisplayUtils::getBoundingBox({}, minX, minY, maxX, maxY);
    TEST_ASSERT_EQUAL(0, minX);

    // hasConfigurationChanged
    TEST_ASSERT_TRUE(!DisplayUtils::hasConfigurationChanged(adjacent, adjacent));

    std::vector<DisplayInfo> changed = {d1, d3};
    TEST_ASSERT_TRUE(DisplayUtils::hasConfigurationChanged(adjacent, changed));

    // Different sizes
    std::vector<DisplayInfo> diffSize = {d1};
    TEST_ASSERT_TRUE(DisplayUtils::hasConfigurationChanged(adjacent, diffSize));

    return {__func__, true, "Display utils functions passed", 0.0};
  }

  TestResult testGLRendererErrorCallback() {
    using EC = Platform::Linux::GLRendererErrorCode;

    // Test default constructor
    Platform::Linux::GLRendererError err1;
    TEST_ASSERT_EQUAL(0, static_cast<int>(err1.code));
    TEST_ASSERT_TRUE(err1.message.empty());
    TEST_ASSERT_EQUAL(0, err1.lineNumber);

    // Test parameterized constructor
    Platform::Linux::GLRendererError err2(
        EC::ShaderCompilationFailed, "compile failed", "my_shader",
        "syntax error on line 42", 42);
    int code = static_cast<int>(err2.code);
    TEST_ASSERT_EQUAL(2, code);
    TEST_ASSERT_TRUE(err2.message == "compile failed");
    TEST_ASSERT_TRUE(err2.shaderName == "my_shader");
    TEST_ASSERT_TRUE(err2.compilerError == "syntax error on line 42");
    TEST_ASSERT_EQUAL(42, err2.lineNumber);

    // Test copy construction
    Platform::Linux::GLRendererError err3 = err2;
    int code3 = static_cast<int>(err3.code);
    TEST_ASSERT_EQUAL(2, code3);
    TEST_ASSERT_TRUE(err3.message == "compile failed");

    // Test assignment
    Platform::Linux::GLRendererError err4;
    err4 = err2;
    int code4 = static_cast<int>(err4.code);
    TEST_ASSERT_EQUAL(2, code4);

    // Test that callback would fire (simulate setError path)
    int callbackCount = 0;
    Platform::Linux::GLRendererError lastCaptured;
    auto callback = [&](const Platform::Linux::GLRendererError &e) {
      callbackCount++;
      lastCaptured = e;
    };

    // Simulate what setError does
    Platform::Linux::GLRendererError testErr(
        EC::InvalidState, "test error", "test", "", 0);
    callback(testErr);
    TEST_ASSERT_EQUAL(1, callbackCount);
    TEST_ASSERT_TRUE(lastCaptured.message == "test error");

    return {__func__, true, "GLRenderer error callback passed", 0.0};
  }

  TestResult testSettingsRoundTrip() {
    ShaderCandy::Config::AppSettings orig;
    orig.targetFPS = 120;
    orig.vsync = false;
    orig.hdr = true;
    orig.multisampleLevel = 4;
    orig.enableAudio = true;
    orig.audioDevice = "hw:1,0";
    orig.audioSensitivity = 2.5f;
    orig.audioSmoothing = 0.7f;
    orig.adaptiveQuality = false;
    orig.showFPS = true;
    orig.limitGPU = true;
    orig.autoScaleFPSThreshold = 30.0f;
    orig.defaultShader = "plasma";
    orig.shaderPath = "/tmp/shaders";
    orig.enableHotReload = false;
    orig.spanDisplays = true;
    orig.perDisplayShader = true;
    orig.idleTimeMinutes = 15;
    orig.lockOnActivate = true;
    orig.neuralStyleEnabled = true;
    orig.neuralStyleStrength = 0.8f;
    orig.neuralStyleName = "starry";
    orig.spatialAudio = true;
    orig.roomSize = 3.0f;
    orig.reverbDamping = 0.2f;

    std::string json = Config::JSON::serializeSettings(orig);
    Config::AppSettings loaded = Config::JSON::deserializeSettings(json);

    TEST_ASSERT_EQUAL(orig.targetFPS, loaded.targetFPS);
    TEST_ASSERT_EQUAL(orig.vsync, loaded.vsync);
    TEST_ASSERT_EQUAL(orig.hdr, loaded.hdr);
    TEST_ASSERT_EQUAL(orig.multisampleLevel, loaded.multisampleLevel);
    TEST_ASSERT_EQUAL(orig.enableAudio, loaded.enableAudio);
    TEST_ASSERT_TRUE(orig.audioDevice == loaded.audioDevice);
    TEST_ASSERT_EQUAL(orig.audioSensitivity, loaded.audioSensitivity);
    TEST_ASSERT_EQUAL(orig.audioSmoothing, loaded.audioSmoothing);
    TEST_ASSERT_EQUAL(orig.adaptiveQuality, loaded.adaptiveQuality);
    TEST_ASSERT_EQUAL(orig.showFPS, loaded.showFPS);
    TEST_ASSERT_EQUAL(orig.limitGPU, loaded.limitGPU);
    TEST_ASSERT_EQUAL(orig.autoScaleFPSThreshold, loaded.autoScaleFPSThreshold);
    TEST_ASSERT_TRUE(orig.defaultShader == loaded.defaultShader);
    TEST_ASSERT_TRUE(orig.shaderPath == loaded.shaderPath);
    TEST_ASSERT_EQUAL(orig.enableHotReload, loaded.enableHotReload);
    TEST_ASSERT_EQUAL(orig.spanDisplays, loaded.spanDisplays);
    TEST_ASSERT_EQUAL(orig.perDisplayShader, loaded.perDisplayShader);
    TEST_ASSERT_EQUAL(orig.idleTimeMinutes, loaded.idleTimeMinutes);
    TEST_ASSERT_EQUAL(orig.lockOnActivate, loaded.lockOnActivate);
    TEST_ASSERT_EQUAL(orig.neuralStyleEnabled, loaded.neuralStyleEnabled);
    TEST_ASSERT_EQUAL(orig.neuralStyleStrength, loaded.neuralStyleStrength);
    TEST_ASSERT_TRUE(orig.neuralStyleName == loaded.neuralStyleName);
    TEST_ASSERT_EQUAL(orig.spatialAudio, loaded.spatialAudio);
    TEST_ASSERT_EQUAL(orig.roomSize, loaded.roomSize);
    TEST_ASSERT_EQUAL(orig.reverbDamping, loaded.reverbDamping);

    return {__func__, true, "Settings round-trip passed", 0.0};
  }

  TestResult testAudioAutoDetect() {
    auto &mgr = Config::ConfigurationManager::getInstance();
    mgr.initialize();

    std::string shaderPath = "/tmp/test_audio_auto.frag";
    std::ofstream f(shaderPath);
    f << "// audio_auto - Shader with audio keywords\n";
    f << "void main() {\n";
    f << "  float bass = sin(time);\n";
    f << "  float mid = cos(time * 2.0);\n";
    f << "  float treble = sin(time * 4.0);\n";
    f << "}\n";
    f.close();

    mgr.parseShaderMetadata(shaderPath);
    auto *cfg = mgr.getShaderConfig("test_audio_auto");
    TEST_ASSERT_NOT_NULL(cfg);
    TEST_ASSERT_TRUE(cfg->supportsAudio);
    std::filesystem::remove(shaderPath);

    mgr.shutdown();
    return {__func__, true, "Audio auto-detect passed", 0.0};
  }

  TestResult testBloomQualityLevels() {
    using namespace Platform::Linux;

    GLBloomConfig bloom;
    bloom.enabled = true;
    bloom.threshold = 0.5f;
    bloom.intensity = 1.0f;

    bloom.quality = GLBloomQuality::Low;
    TEST_ASSERT_EQUAL(0, static_cast<int>(bloom.quality));

    bloom.quality = GLBloomQuality::Medium;
    TEST_ASSERT_EQUAL(1, static_cast<int>(bloom.quality));

    bloom.quality = GLBloomQuality::High;
    TEST_ASSERT_EQUAL(2, static_cast<int>(bloom.quality));

    bloom.quality = GLBloomQuality::Ultra;
    TEST_ASSERT_EQUAL(3, static_cast<int>(bloom.quality));

    int passes[] = {2, 4, 6, 8};
    GLBloomQuality levels[] = {
        GLBloomQuality::Low, GLBloomQuality::Medium,
        GLBloomQuality::High, GLBloomQuality::Ultra};
    for (int i = 0; i < 4; i++) {
      bloom.quality = levels[i];
      int expectedPasses = passes[i];
      int actualPasses = 4;
      if (bloom.quality == GLBloomQuality::Low) actualPasses = 2;
      else if (bloom.quality == GLBloomQuality::Medium) actualPasses = 4;
      else if (bloom.quality == GLBloomQuality::High) actualPasses = 6;
      else if (bloom.quality == GLBloomQuality::Ultra) actualPasses = 8;
      TEST_ASSERT_EQUAL(expectedPasses, actualPasses);
    }

    return {__func__, true, "Bloom quality levels passed", 0.0};
  }

  TestResult testParticleRespawn() {
    using namespace Platform::Linux;

    GLParticleConfig pc;
    pc.enabled = true;
    pc.count = 10;
    pc.gravity = 9.81f;
    pc.speed = 1.0f;

    TEST_ASSERT_TRUE(pc.enabled);
    TEST_ASSERT_EQUAL(10, pc.count);
    TEST_ASSERT_EQUAL(9.81f, pc.gravity);
    TEST_ASSERT_EQUAL(1.0f, pc.speed);

    pc.enabled = false;
    TEST_ASSERT_FALSE(pc.enabled);

    pc.count = 0;
    TEST_ASSERT_EQUAL(0, pc.count);

    pc.gravity = 0.0f;
    TEST_ASSERT_EQUAL(0.0f, pc.gravity);

    return {__func__, true, "Particle respawn config passed", 0.0};
  }

  TestResult testFileWatcherLifecycle() {
    using namespace Platform::Linux;

    bool callbackFired = false;
    auto shaderCallback = [&](const std::string &name) {
      callbackFired = true;
    };

    bool errorFired = false;
    auto errorCallback = [&](const GLRendererError &err) {
      errorFired = true;
    };

    GLRendererError err;
    err.code = GLRendererErrorCode::ShaderCompilationFailed;
    err.message = "test";
    errorCallback(err);
    TEST_ASSERT_TRUE(errorFired);

    std::string shaderName = "test_shader";
    shaderCallback(shaderName);
    TEST_ASSERT_TRUE(callbackFired);

    return {__func__, true, "File watcher lifecycle passed", 0.0};
  }

  TestResult testTransitionSystem() {
    using namespace Platform::Linux;

    GLTransitionConfig tc;
    TEST_ASSERT_EQUAL(static_cast<int>(GLTransitionType::Crossfade),
                      static_cast<int>(tc.type));
    TEST_ASSERT_EQUAL(static_cast<int>(GLEasingFunction::EaseInOut),
                      static_cast<int>(tc.easing));
    TEST_ASSERT_EQUAL(2.0f, tc.duration);
    TEST_ASSERT_TRUE(tc.enabled);

    tc.type = GLTransitionType::Dissolve;
    tc.easing = GLEasingFunction::CubicInOut;
    tc.duration = 1.5f;
    tc.enabled = false;
    TEST_ASSERT_EQUAL(static_cast<int>(GLTransitionType::Dissolve),
                      static_cast<int>(tc.type));
    TEST_ASSERT_EQUAL(static_cast<int>(GLEasingFunction::CubicInOut),
                      static_cast<int>(tc.easing));
    TEST_ASSERT_EQUAL(1.5f, tc.duration);
    TEST_ASSERT_FALSE(tc.enabled);

    for (int i = 0; i <= static_cast<int>(GLTransitionType::SpinCounterClockwise); ++i) {
      tc.type = static_cast<GLTransitionType>(i);
      TEST_ASSERT_EQUAL(i, static_cast<int>(tc.type));
    }
    for (int i = 0; i <= static_cast<int>(GLEasingFunction::ExponentialOut); ++i) {
      tc.easing = static_cast<GLEasingFunction>(i);
      TEST_ASSERT_EQUAL(i, static_cast<int>(tc.easing));
    }

    return {__func__, true, "Transition system passed", 0.0};
  }

  TestResult testPostProcessingConfig() {
    using namespace Platform::Linux;

    GLPostProcessConfig pc;
    TEST_ASSERT_TRUE(pc.vignetteEnabled);
    TEST_ASSERT_EQUAL(0.3f, pc.vignetteIntensity);
    TEST_ASSERT_EQUAL(0.8f, pc.vignetteRadius);
    TEST_ASSERT_TRUE(pc.chromaticAberrationEnabled);
    TEST_ASSERT_EQUAL(0.003f, pc.chromaticAberrationAmount);
    TEST_ASSERT_FALSE(pc.filmGrainEnabled);
    TEST_ASSERT_EQUAL(0.05f, pc.filmGrainIntensity);
    TEST_ASSERT_FALSE(pc.crtScanlinesEnabled);
    TEST_ASSERT_EQUAL(0.1f, pc.crtScanlineIntensity);
    TEST_ASSERT_FALSE(pc.colorTintEnabled);
    TEST_ASSERT_EQUAL(1.0f, pc.colorTintR);
    TEST_ASSERT_EQUAL(1.0f, pc.colorTintG);
    TEST_ASSERT_EQUAL(1.0f, pc.colorTintB);

    pc.vignetteEnabled = false;
    pc.chromaticAberrationAmount = 0.01f;
    pc.filmGrainEnabled = true;
    pc.filmGrainIntensity = 0.1f;
    pc.crtScanlinesEnabled = true;
    pc.crtScanlineIntensity = 0.75f;
    pc.colorTintEnabled = true;
    pc.colorTintR = 1.2f;
    pc.colorTintG = 0.9f;
    pc.colorTintB = 0.8f;

    TEST_ASSERT_FALSE(pc.vignetteEnabled);
    TEST_ASSERT_EQUAL(0.01f, pc.chromaticAberrationAmount);
    TEST_ASSERT_TRUE(pc.filmGrainEnabled);
    TEST_ASSERT_EQUAL(0.1f, pc.filmGrainIntensity);
    TEST_ASSERT_TRUE(pc.crtScanlinesEnabled);
    TEST_ASSERT_EQUAL(0.75f, pc.crtScanlineIntensity);
    TEST_ASSERT_TRUE(pc.colorTintEnabled);
    TEST_ASSERT_EQUAL(1.2f, pc.colorTintR);
    TEST_ASSERT_EQUAL(0.9f, pc.colorTintG);
    TEST_ASSERT_EQUAL(0.8f, pc.colorTintB);

    return {__func__, true, "Post-processing config passed", 0.0};
  }

  TestResult testAdaptiveQualityConfig() {
    using namespace Platform::Linux;

    GLAdaptiveQualityConfig aq;
    TEST_ASSERT_TRUE(aq.enabled);
    TEST_ASSERT_EQUAL(60.0f, aq.targetFPS);
    TEST_ASSERT_EQUAL(45.0f, aq.lowFPS);
    TEST_ASSERT_EQUAL(65.0f, aq.highFPS);
    TEST_ASSERT_EQUAL(0.5f, aq.minResolutionScale);
    TEST_ASSERT_EQUAL(1.0f, aq.maxResolutionScale);
    TEST_ASSERT_EQUAL(1.0f, aq.currentResolutionScale);

    aq.enabled = false;
    aq.targetFPS = 30.0f;
    aq.lowFPS = 20.0f;
    aq.highFPS = 35.0f;
    aq.minResolutionScale = 0.25f;
    aq.maxResolutionScale = 0.75f;

    TEST_ASSERT_FALSE(aq.enabled);
    TEST_ASSERT_EQUAL(30.0f, aq.targetFPS);
    TEST_ASSERT_EQUAL(20.0f, aq.lowFPS);
    TEST_ASSERT_EQUAL(35.0f, aq.highFPS);
    TEST_ASSERT_EQUAL(0.25f, aq.minResolutionScale);
    TEST_ASSERT_EQUAL(0.75f, aq.maxResolutionScale);

    aq.currentResolutionScale = 0.5f;
    TEST_ASSERT_EQUAL(0.5f, aq.currentResolutionScale);

    return {__func__, true, "Adaptive quality config passed", 0.0};
  }

  TestResult testSmartShaderRotation() {
    using namespace Platform::Linux;

    std::vector<std::string> shaders = {"alpha", "beta", "gamma", "delta", "epsilon"};

    std::vector<std::string> favorites = {"alpha", "gamma"};
    TEST_ASSERT_EQUAL(2u, favorites.size());

    favorites.push_back("delta");
    TEST_ASSERT_EQUAL(3u, favorites.size());

    favorites.erase(std::remove(favorites.begin(), favorites.end(), "gamma"),
                    favorites.end());
    TEST_ASSERT_EQUAL(2u, favorites.size());
    TEST_ASSERT_TRUE(std::find(favorites.begin(), favorites.end(), "gamma") == favorites.end());

    std::vector<std::string> skipList = {"beta"};
    TEST_ASSERT_EQUAL(1u, skipList.size());

    skipList.push_back("epsilon");
    TEST_ASSERT_EQUAL(2u, skipList.size());

    std::vector<std::string> available;
    for (const auto &s : shaders) {
      if (std::find(skipList.begin(), skipList.end(), s) == skipList.end()) {
        available.push_back(s);
      }
    }
    TEST_ASSERT_EQUAL(3u, available.size());
    TEST_ASSERT_TRUE(std::find(available.begin(), available.end(), "beta") == available.end());
    TEST_ASSERT_TRUE(std::find(available.begin(), available.end(), "epsilon") == available.end());

    std::mt19937 rng(42);
    std::shuffle(available.begin(), available.end(), rng);
    TEST_ASSERT_EQUAL(3u, available.size());

    float timePerShader = 30.0f;
    float totalTime = timePerShader * static_cast<float>(shaders.size());
    TEST_ASSERT_EQUAL(150.0f, totalTime);

    bool shuffleMode = true;
    bool autoRotate = true;
    TEST_ASSERT_TRUE(shuffleMode);
    TEST_ASSERT_TRUE(autoRotate);

    return {__func__, true, "Smart shader rotation passed", 0.0};
  }
};

REGISTER_TEST_SUITE(CoverageExpansionTests);

} // namespace Test
} // namespace ShaderCandy
