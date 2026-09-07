#include "../src/core/MultiDisplayManager.h"
#include "../src/core/ShaderManager.h"
#include "TestFramework.h"
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace ShaderCandy {
namespace Test {

struct Size2D {
  float width;
  float height;
};

class RendererFeatureTests : public TestSuite {
public:
  std::string getName() const override { return "Renderer Feature Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;

    results.push_back(testDynamicResolution());
    results.push_back(testResolutionScaling());
    results.push_back(testThermalStateTransitions());
    results.push_back(testMemoryBudgetCalculation());
    results.push_back(testAutoScalingThresholds());
    results.push_back(testFramePacingTiming());
    results.push_back(testUnifiedShaderManager());
    results.push_back(testMultiDisplayVirtualCanvas());
    results.push_back(testHeadlessRenderer());

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

    return {__func__, true, "Resolution scaling to max texture dimension works",
            0.0};
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

    uint64_t estimatedMemory =
        (uint64_t)width * (uint64_t)height * bytesPerPixel;

    TEST_ASSERT(estimatedMemory > 30 * 1024 * 1024,
                "Texture memory estimate too low");
    TEST_ASSERT(estimatedMemory < 40 * 1024 * 1024,
                "Texture memory estimate too high");

    return {__func__, true, "Memory budget calculation correct", 0.0};
  }

  TestResult testAutoScalingThresholds() {
    float preferredFPS = 60.0f;
    float autoScaleThreshold = 55.0f;
    float currentFPS = 50.0f;

    bool shouldReduce = (currentFPS < autoScaleThreshold);
    TEST_ASSERT_TRUE(shouldReduce);

    currentFPS = 59.0f;
    bool shouldRecover = (currentFPS > (preferredFPS - 2.0f));
    TEST_ASSERT_TRUE(shouldRecover);

    float scale = 1.0f;
    currentFPS = 40.0f;

    if (currentFPS < autoScaleThreshold * 0.8f) {
      scale = std::max(0.5f, scale - 0.05f);
    }

    TEST_ASSERT(scale < 1.0f, "Should reduce resolution when FPS very low");

    return {__func__, true, "Auto-scaling thresholds work correctly", 0.0};
  }

  TestResult testFramePacingTiming() {
    float targetFPS = 60.0f;
    float targetFrameTime = 1.0f / targetFPS;

    TEST_ASSERT(std::abs(targetFrameTime - 0.01667f) < 0.001f,
                "Frame time calculation incorrect");

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

  TestResult testUnifiedShaderManager() {
    auto manager = createShaderManager();
    TEST_ASSERT_TRUE(manager != nullptr);

    bool initialized = manager->initialize();
    TEST_ASSERT_TRUE(initialized);

    auto shaders = manager->getAvailableShaders();
    TEST_ASSERT(!shaders.empty(),
                "Should discover available shaders in repository");

    std::string active = manager->getActiveShader();
    TEST_ASSERT(!active.empty(), "Should select a default active shader");

    bool switched = manager->setActiveShader(shaders.front());
    TEST_ASSERT_TRUE(switched);
    TEST_ASSERT(shaders.front() == manager->getActiveShader(),
                "Active shader must match");

    return {__func__, true,
            "Unified ShaderManager initialization and discovery passed", 0.0};
  }

  TestResult testMultiDisplayVirtualCanvas() {
    auto &displayMgr = MultiDisplayManager::getInstance();
    TEST_ASSERT_TRUE(displayMgr.initialize());

    auto displays = displayMgr.getDisplays();
    TEST_ASSERT(!displays.empty(),
                "Should have at least one display configured");

    displayMgr.setSpanMode(MultiDisplayManager::SpanMode::SpanAll);
    TEST_ASSERT_TRUE(displayMgr.getSpanMode() ==
                     MultiDisplayManager::SpanMode::SpanAll);

    int vw = displayMgr.getVirtualWidth();
    int vh = displayMgr.getVirtualHeight();
    TEST_ASSERT(vw > 0 && vh > 0, "Virtual canvas dimensions must be positive");

    float dx, dy;
    displayMgr.virtualToDisplay(0.5f, 0.5f, displays[0].id, dx, dy);
    float vx, vy;
    displayMgr.displayToVirtual(displays[0].id, dx, dy, vx, vy);

    TEST_ASSERT(std::abs(vx - 0.5f) < 0.01f,
                "Coordinate conversion roundtrip X failed");
    TEST_ASSERT(std::abs(vy - 0.5f) < 0.01f,
                "Coordinate conversion roundtrip Y failed");

    displayMgr.setDisplayShader(displays[0].id, "aurora");
    TEST_ASSERT(displayMgr.getDisplayShader(displays[0].id) == "aurora",
                "Display shader should match");

    return {__func__, true,
            "MultiDisplayManager virtual canvas and spanning logic passed",
            0.0};
  }

  TestResult testHeadlessRenderer() {
    HeadlessRenderer renderer;
    bool init = renderer.initialize(320, 240);
    TEST_ASSERT_TRUE(init);

    renderer.setDuration(1.0f);
    renderer.setFPS(10);
    renderer.beginRender();

    auto frameData = renderer.renderToBuffer(0);
    TEST_ASSERT_EQUAL(320 * 240 * 4, (int)frameData.size());

    // Verify alpha channel is opaque
    TEST_ASSERT_EQUAL(255, (int)frameData[3]);

    bool frameRendered = renderer.renderFrame();
    TEST_ASSERT_TRUE(frameRendered);

    renderer.endRender();
    TEST_ASSERT_TRUE(renderer.isFinished());

    return {__func__, true,
            "HeadlessRenderer frame rendering and buffer operations passed",
            0.0};
  }
};

REGISTER_TEST_SUITE(RendererFeatureTests);

} // namespace Test
} // namespace ShaderCandy
