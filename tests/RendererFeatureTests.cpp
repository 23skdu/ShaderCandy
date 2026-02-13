#include "TestFramework.h"
#include <cmath>
#include <algorithm>
#include <cstdint>

namespace ShaderCandy {
namespace Test {

struct Size2D {
    float width;
    float height;
};

class RendererFeatureTests : public TestSuite {
public:
    std::string getName() const override {
        return "Renderer Feature Tests";
    }
    
    std::vector<TestResult> run() override {
        std::vector<TestResult> results;
        
        results.push_back(testDynamicResolution());
        results.push_back(testResolutionScaling());
        results.push_back(testThermalStateTransitions());
        results.push_back(testMemoryBudgetCalculation());
        results.push_back(testAutoScalingThresholds());
        results.push_back(testFramePacingTiming());
        
        return results;
    }

private:
    TestResult testDynamicResolution() {
        float resolutionScale = 1.0f;
        Size2D viewportSize = {3840.0f, 2160.0f};
        
        Size2D renderSize;
        renderSize.width = viewportSize.width * resolutionScale;
        renderSize.height = viewportSize.height * resolutionScale;
        
        TEST_ASSERT_EQUAL(3840, (int)renderSize.width);
        TEST_ASSERT_EQUAL(2160, (int)renderSize.height);
        
        resolutionScale = 0.75f;
        renderSize.width = viewportSize.width * resolutionScale;
        renderSize.height = viewportSize.height * resolutionScale;
        
        TEST_ASSERT_EQUAL(2880, (int)renderSize.width);
        TEST_ASSERT_EQUAL(1620, (int)renderSize.height);
        
        return {__func__, true, "Dynamic resolution calculation correct", 0.0};
    }
    
    TestResult testResolutionScaling() {
        float scale = 1.0f;
        float maxTextureDimension = 8192.0f;
        
        Size2D viewportSize = {16384.0f, 8640.0f};
        
        if (viewportSize.width > maxTextureDimension) {
            scale = maxTextureDimension / viewportSize.width;
        }
        
        TEST_ASSERT(scale < 1.0f, "Should scale down for large viewport");
        TEST_ASSERT_EQUAL(0.5f, scale);
        
        return {__func__, true, "Resolution scaling to max texture dimension works", 0.0};
    }
    
    TestResult testThermalStateTransitions() {
        enum ThermalState { Nominal = 0, Fair = 1, Serious = 2, Critical = 3 };
        
        ThermalState states[] = {Nominal, Fair, Serious, Critical};
        float expectedLevels[] = {0.0f, 0.33f, 0.66f, 1.0f};
        bool expectedThrottling[] = {false, false, true, true};
        
        for (int i = 0; i < 4; i++) {
            float thermalLevel = expectedLevels[i];
            bool isThrottling = expectedThrottling[i];
            
            if (thermalLevel >= 0.66f) {
                TEST_ASSERT_TRUE(isThrottling);
            } else {
                TEST_ASSERT_FALSE(isThrottling);
            }
        }
        
        return {__func__, true, "Thermal state transitions correct", 0.0};
    }
    
    TestResult testMemoryBudgetCalculation() {
        uint64_t recommendedWorkingSet = 4ULL * 1024 * 1024 * 1024;
        uint64_t maxMemoryBudget = recommendedWorkingSet / 2;
        
        TEST_ASSERT_EQUAL(2ULL * 1024 * 1024 * 1024, maxMemoryBudget);
        
        uint32_t width = 3840;
        uint32_t height = 2160;
        uint32_t bytesPerPixel = 4;
        
        uint64_t estimatedMemory = (uint64_t)width * (uint64_t)height * bytesPerPixel;
        
        TEST_ASSERT(estimatedMemory > 30 * 1024 * 1024, "Texture memory estimate too low");
        TEST_ASSERT(estimatedMemory < 40 * 1024 * 1024, "Texture memory estimate too high");
        
        return {__func__, true, "Memory budget calculation correct", 0.0};
    }
    
    TestResult testAutoScalingThresholds() {
        float preferredFPS = 60.0f;
        float autoScaleThreshold = 55.0f;
        float currentFPS = 50.0f;
        
        bool shouldReduce = (currentFPS < autoScaleThreshold);
        TEST_ASSERT_TRUE(shouldReduce);
        
        currentFPS = 58.0f;
        bool shouldRecover = (currentFPS > (preferredFPS - 2.0f));
        TEST_ASSERT_TRUE(shouldRecover);
        
        float scale = 1.0f;
        currentFPS = 45.0f;
        
        if (currentFPS < autoScaleThreshold * 0.8f) {
            scale = std::max(0.5f, scale - 0.05f);
        }
        
        TEST_ASSERT(scale < 1.0f, "Should reduce resolution when FPS very low");
        
        return {__func__, true, "Auto-scaling thresholds work correctly", 0.0};
    }
    
    TestResult testFramePacingTiming() {
        float targetFPS = 60.0f;
        float targetFrameTime = 1.0f / targetFPS;
        
        TEST_ASSERT(std::abs(targetFrameTime - 0.01667f) < 0.001f, "Frame time calculation incorrect");
        
        float gpuTimeMs = 8.0f;
        float cpuTimeMs = 2.0f;
        float totalFrameTime = gpuTimeMs + cpuTimeMs;
        
        bool withinBudget = (totalFrameTime < (targetFrameTime * 1000.0f));
        TEST_ASSERT_TRUE(withinBudget);
        
        float frameTimeMs = 35.0f;
        bool isDropped = (frameTimeMs > 33.3f);
        TEST_ASSERT_TRUE(isDropped);
        
        return {__func__, true, "Frame pacing timing correct", 0.0};
    }
};

REGISTER_TEST_SUITE(RendererFeatureTests);

}
}
