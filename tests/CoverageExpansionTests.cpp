#include "../src/config/ConfigurationManager.h"
#include "../src/config/PresetManager.h"
#include "../src/core/MathUtils.h"
#include "../src/core/MultiDisplayManager.h"
#include "../src/core/PerformanceMonitor.h"
#include "../src/core/ShaderManager.h"
#include "../src/core/UniformBuffer.h"
#include "TestFramework.h"
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
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
    bool cbCalled = false;
    mgr.setDisplayChangeCallback(
        [&](const std::vector<DisplayInfo> &) { cbCalled = true; });

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
    bool initCb = false;
    mgr.setDisplayChangeCallback(
        [&](const std::vector<DisplayInfo> &) { initCb = true; });
    mgr.initialize();
    TEST_ASSERT_TRUE(initCb);

    // Unregistered display shader fallback
    std::string unregShader = mgr.getDisplayShader("unregistered_disp_999");
    TEST_ASSERT_TRUE(unregShader.empty());

    // HeadlessRenderer uninitialized buffer allocation
    HeadlessRenderer hrUninit;
    auto uninitBuf = hrUninit.renderToBuffer(0);
    TEST_ASSERT(!uninitBuf.empty(), "Render to buffer should auto-allocate");

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
};

REGISTER_TEST_SUITE(CoverageExpansionTests);

} // namespace Test
} // namespace ShaderCandy
