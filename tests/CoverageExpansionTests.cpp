#include "../src/core/MathUtils.h"
#include "../src/core/UniformBuffer.h"
#include "../src/core/PerformanceMonitor.h"
#include "../src/core/ShaderManager.h"
#include "../src/config/ConfigurationManager.h"
#include "../src/config/PresetManager.h"
#include "TestFramework.h"
#include <cmath>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <thread>
#include <variant>

namespace ShaderCandy {
namespace Test {

class CoverageExpansionTests : public TestSuite {
public:
    CoverageExpansionTests() { std::cout << "DEBUG: CoverageExpansionTests constructed" << std::endl; }
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
        TEST_ASSERT(std::abs(n.length() - 1.0f) < 0.0001f, "Normalize length incorrect");
        
        // normalize zero vector
        Math::Vec3 zero(0, 0, 0);
        Math::Vec3 nZero = zero.normalize();
        TEST_ASSERT(std::abs(nZero.x) < 0.001f, "Zero normalize x error");

        // Dot and Cross
        Math::Vec3 v1(1, 0, 0), v2_vec(0, 1, 0);
        TEST_ASSERT(std::abs(Math::dot(v1, v2_vec)) < 0.0001f, "Dot product failed");
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
        TEST_ASSERT(buffer.getData().frame == initialFrame + 1, "advanceFrame counter failed");

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
        virtual bool loadShader(const std::string&, const std::string&) override { return true; }
        virtual bool reloadShaders() override { return true; }
        virtual std::vector<std::string> getAvailableShaders() const override { return {}; }
        virtual bool setActiveShader(const std::string&) override { return true; }
        virtual std::string getActiveShader() const override { return ""; }
        virtual void render() override {}
    };

    TestResult testShaderManagerBase() {
        MockShaderManager sm;
        sm.setHotReload(true);
        TEST_ASSERT_TRUE(sm.isHotReloadEnabled());
        sm.setShaderChangedCallback([](const std::string&){});
        return {__func__, true, "ShaderManager base coverage passed", 0.0};
    }

    TestResult testConfigManagerExpansion() {
        Config::ConfigurationManager &mgr = Config::ConfigurationManager::getInstance();
        mgr.initialize();
        
        // JSON Edge Cases
        std::string escaped = Config::JSON::escapeJSON("line1\nline2\ttab\rreturn\"quote\\back");
        TEST_ASSERT(escaped.find("\\n") != std::string::npos, "JSON escape failed");
        TEST_ASSERT(escaped.find("\\\"") != std::string::npos, "JSON escape failed");

        // Test invalid JSON variants
        TEST_ASSERT(Config::JSON::parse("{ invalid }").empty(), "Invalid JSON parse failed");
        TEST_ASSERT(Config::JSON::parse("{\"key\":").empty(), "Truly incomplete JSON should return empty");
        TEST_ASSERT(Config::JSON::parse("{").empty(), "Trivial incomplete JSON should return empty");

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
        TEST_ASSERT(fromDict.modifiedDate == preset.modifiedDate, "FromDictionary date mismatch");

        // Error Handling
        std::string error;
        TEST_ASSERT(!pm.loadPreset("/nonexistent/preset.json", error).has_value(), "Should fail to load non-existent");
        TEST_ASSERT(!pm.deletePreset("/nonexistent/preset.json", error), "Should fail to delete non-existent");

        // Discovery in non-existent
        auto discovered = pm.discoverPresets("/nonexistent/presets");
        TEST_ASSERT(discovered.empty(), "Discovery in non-existent should be empty");

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
            sm->setShaderChangedCallback([](const std::string&){});
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
        for (int i=0; i<6; i++) {
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
        for(size_t i=0; i<count; i++) TEST_ASSERT_EQUAL(2.0f, res[i]);
        
        Math::multiplyArray(res.data(), a.data(), b.data(), 0);
        Math::sumArray(a.data(), 0);
        Math::lerpArray(res.data(), a.data(), b.data(), 0.5f, 0);

        float sum = Math::sumArray(a.data(), count);
        TEST_ASSERT_EQUAL(7.0f, sum);
        
        Math::lerpArray(res.data(), a.data(), b.data(), 0.5f, count);
        for(size_t i=0; i<count; i++) TEST_ASSERT_EQUAL(1.5f, res[i]);
        
        return {__func__, true, "SIMD alignment edge cases passed", 0.0};
    }

    TestResult testJSONParsingMore() {
        // Unicode escapes
        auto dict = Config::JSON::parse("{\"key\": \"\\u1234\"}");
        // Note: our simple parser might not actually decode \u1234 but should run the branch
        
        // Complex escaping
        std::string json = "{\"a\": \"\\\\\", \"b\": \"\\\"\", \"c\": \"\\/\", \"d\": \"\\b\", \"e\": \"\\f\", \"f\": \"\\n\", \"r\": \"\\r\", \"t\": \"\\t\"}";
        Config::JSON::parse(json);

        return {__func__, true, "JSON parsing expansion passed", 0.0};
    }
};

REGISTER_TEST_SUITE(CoverageExpansionTests);

} // namespace Test
} // namespace ShaderCandy
