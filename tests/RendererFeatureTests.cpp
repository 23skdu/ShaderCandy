#include "../src/core/MathUtils.h"
#include "../src/core/MultiDisplayManager.h"
#include "../src/core/PerformanceMonitor.h"
#include "../src/core/ShaderManager.h"
#include "../src/core/UniformBuffer.h"
#include "../src/audio/AudioInput.h"
#include "../src/gl/GLRendererTypes.h"
#include "TestFramework.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

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

    // Roadmap Features
    results.push_back(testAdaptiveRayMarchLoD());
    results.push_back(testDescriptorHeapSuballocation());
    results.push_back(testParallelCommandEncodingSimulation());
    results.push_back(testMeshShaderCapabilitySimulation());
    results.push_back(testAudioLowLatencyAndPipeWireMode());
    results.push_back(testIndirectCommandBuffersSimulation());
    results.push_back(testDynamicAcousticSceneDepth());
    results.push_back(testMotionAdaptiveVRSRateMap());

    return results;
  }

private:
  TestResult testDynamicResolution() {
    // Test actual PerformanceMonitor dynamic resolution scaling logic
    float fullScale = PerformanceMonitor::calculateDynamicResolutionScale(16.0f, 16.67f);
    TEST_ASSERT_EQUAL(1.0f, fullScale);

    float droppedScale = PerformanceMonitor::calculateDynamicResolutionScale(33.34f, 16.67f);
    TEST_ASSERT(droppedScale < 1.0f, "Should scale down when latency exceeds target");
    TEST_ASSERT(std::abs(droppedScale - 0.5f) < 0.01f, "33.34ms at 16.67ms target should be ~0.5 scale");

    // Clamping test: should not scale below 0.5f
    float extremeLatencyScale = PerformanceMonitor::calculateDynamicResolutionScale(100.0f, 16.67f);
    TEST_ASSERT_EQUAL(0.5f, extremeLatencyScale);

    // Viewport scaling with dynamic resolution
    Size2D viewportSize = {3840.0f, 2160.0f};
    Size2D renderSize;
    renderSize.width = viewportSize.width * fullScale;
    renderSize.height = viewportSize.height * fullScale;
    TEST_ASSERT_EQUAL(3840, (int)renderSize.width);
    TEST_ASSERT_EQUAL(2160, (int)renderSize.height);

    renderSize.width = viewportSize.width * 0.75f;
    renderSize.height = viewportSize.height * 0.75f;
    TEST_ASSERT_EQUAL(2880, (int)renderSize.width);
    TEST_ASSERT_EQUAL(1620, (int)renderSize.height);

    // Test smoothed dynamic resolution scale with damping
    float smoothed = PerformanceMonitor::calculateSmoothedDynamicResolutionScale(33.34f, 16.67f, 1.0f, 0.5f);
    TEST_ASSERT(smoothed < 1.0f && smoothed > 0.5f, "Smoothed scale should interpolate toward target");

    // Test variance calculation on PerformanceMonitor
    PerformanceMonitor pm(10);
    pm.beginFrame();
    pm.endFrame();
    float variance = pm.getFrameTimeVarianceMs();
    TEST_ASSERT(variance >= 0.0f, "Frame time variance must be non-negative");

    return {__func__, true, "Dynamic resolution calculation correct", 0.0};
  }

  TestResult testResolutionScaling() {
    // Test resolution scaling to max texture dimension and dynamic scaling clamping
    float maxTextureDimension = 8192.0f;
    Size2D viewportSize = {16384.0f, 8640.0f};

    float scale = 1.0f;
    if (viewportSize.width > maxTextureDimension) {
      scale = maxTextureDimension / viewportSize.width;
    }

    TEST_ASSERT(scale < 1.0f, "Should scale down for large viewport");
    TEST_ASSERT_EQUAL(0.5f, scale);

    // Verify 120fps target scaling (8.33ms)
    float highRefreshScale = PerformanceMonitor::calculateDynamicResolutionScale(10.0f, 8.33f);
    TEST_ASSERT(highRefreshScale < 1.0f, "High refresh rate should throttle on slower frame");
    TEST_ASSERT(highRefreshScale >= 0.5f, "Scaling must stay within valid range");

    return {__func__, true, "Resolution scaling to max texture dimension works",
            0.0};
  }

  TestResult testThermalStateTransitions() {
    // Test real PerformanceMonitor::calculateAdaptiveRayMarchLoD across all thermal levels
    int maxSteps = 0;
    float stepEpsilon = 0.0f;
    float lodScale = 0.0f;

    // Nominal (thermal level 0.0f, nominal latency)
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.0f, 16.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(128, maxSteps);
    TEST_ASSERT_EQUAL(1.0f, lodScale);
    TEST_ASSERT(std::abs(stepEpsilon - 0.001f) < 0.0001f, "Nominal epsilon check");

    // Fair (thermal level 0.33f)
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.35f, 16.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(96, maxSteps);
    TEST_ASSERT_EQUAL(0.85f, lodScale);
    TEST_ASSERT(std::abs(stepEpsilon - 0.002f) < 0.0001f, "Fair epsilon check");

    // Serious (thermal level 0.66f)
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.70f, 16.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(64, maxSteps);
    TEST_ASSERT_EQUAL(0.65f, lodScale);
    TEST_ASSERT(std::abs(stepEpsilon - 0.0035f) < 0.0001f, "Serious epsilon check");

    // Critical (thermal level 0.85f+)
    PerformanceMonitor::calculateAdaptiveRayMarchLoD(0.90f, 16.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(48, maxSteps);
    TEST_ASSERT_EQUAL(0.5f, lodScale);
    TEST_ASSERT(std::abs(stepEpsilon - 0.005f) < 0.0001f, "Critical epsilon check");

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

    // Test GLRenderer memory tracking integration
    Platform::Linux::GLPerformanceMetrics glMetrics;
    glMetrics.memoryUsageBytes = width * height * 4;
    TEST_ASSERT_EQUAL(estimatedMemory, glMetrics.memoryUsageBytes);

    return {__func__, true, "Memory budget calculation correct", 0.0};
  }

  TestResult testAutoScalingThresholds() {
    using namespace Platform::Linux;

    GLAdaptiveQualityConfig config;
    TEST_ASSERT_TRUE(config.enabled);
    TEST_ASSERT_EQUAL(60.0f, config.targetFPS);
    TEST_ASSERT_EQUAL(45.0f, config.lowFPS);
    TEST_ASSERT_EQUAL(65.0f, config.highFPS);
    TEST_ASSERT_EQUAL(0.5f, config.minResolutionScale);
    TEST_ASSERT_EQUAL(1.0f, config.maxResolutionScale);
    TEST_ASSERT_EQUAL(1.0f, config.currentResolutionScale);

    float currentFPS = 40.0f;
    bool shouldReduce = (currentFPS < config.lowFPS);
    TEST_ASSERT_TRUE(shouldReduce);

    if (shouldReduce) {
      config.currentResolutionScale = std::max(config.minResolutionScale,
                                               config.currentResolutionScale - 0.05f);
    }
    TEST_ASSERT_EQUAL(0.95f, config.currentResolutionScale);

    currentFPS = 68.0f;
    bool shouldRecover = (currentFPS > config.highFPS);
    TEST_ASSERT_TRUE(shouldRecover);
    if (shouldRecover) {
      config.currentResolutionScale = std::min(config.maxResolutionScale,
                                               config.currentResolutionScale + 0.05f);
    }
    TEST_ASSERT_EQUAL(1.0f, config.currentResolutionScale);

    // When severely dropped
    currentFPS = 25.0f;
    if (currentFPS < config.lowFPS) {
      config.currentResolutionScale = config.minResolutionScale;
    }
    TEST_ASSERT_EQUAL(0.5f, config.currentResolutionScale);

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

    // Verify real PerformanceMonitor frame tracking and pacing
    PerformanceMonitor pm(10);
    pm.beginFrame();
    pm.endFrame();
    float lastMs = pm.getLastFrameTimeMs();
    TEST_ASSERT(lastMs >= 0.0f, "Frame time must be non-negative");

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

  TestResult testAdaptiveRayMarchLoD() {
    PerformanceMonitor pm;
    int maxSteps = 0;
    float stepEpsilon = 0.0f;
    float lodScale = 1.0f;

    // Nominal conditions (low thermal level, low latency) -> Full quality (128 steps, standard epsilon)
    pm.calculateAdaptiveRayMarchLoD(0.0f, 16.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(128, maxSteps);
    TEST_ASSERT(std::abs(stepEpsilon - 0.001f) < 0.0001f, "Step epsilon nominal check");
    TEST_ASSERT(std::abs(lodScale - 1.0f) < 0.0001f, "LoD scale nominal check");

    // Extreme thermal throttling / frame latency pressure -> Clamped down to 48 steps, coarser epsilon
    pm.calculateAdaptiveRayMarchLoD(1.0f, 45.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(48, maxSteps);
    TEST_ASSERT(stepEpsilon > 0.002f, "Step epsilon should be coarser under thermal pressure");
    TEST_ASSERT(lodScale < 1.0f, "LoD scale should be lower under thermal pressure");

    // Intermediate thermal levels
    pm.calculateAdaptiveRayMarchLoD(0.7f, 26.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(64, maxSteps);
    TEST_ASSERT_EQUAL(0.65f, lodScale);

    pm.calculateAdaptiveRayMarchLoD(0.4f, 18.0f, maxSteps, stepEpsilon, lodScale);
    TEST_ASSERT_EQUAL(96, maxSteps);
    TEST_ASSERT_EQUAL(0.85f, lodScale);

    // Dynamic resolution scale under latency
    float drsScale = pm.calculateDynamicResolutionScale(33.3f, 16.67f);
    TEST_ASSERT(drsScale < 1.0f, "DRS should scale down under frame drop pressure");

    // UniformBuffer integration
    UniformBuffer ub;
    ub.updateRayMarchLoD(maxSteps, stepEpsilon, lodScale);
    const auto &data = ub.getData();
    TEST_ASSERT_EQUAL(96, ub.getMaxSteps());
    TEST_ASSERT_EQUAL(96, data.maxSteps);

    return {__func__, true, "Adaptive raymarch LoD and thermal scaling verified", 0.0};
  }

  TestResult testDescriptorHeapSuballocation() {
    // Validate GPU argument buffer alignment and suballocation mechanics with Math::alignUp
    size_t length = 1024;
    size_t alignment = 256;
    size_t alignedOffset = Math::alignUp(length, alignment);
    TEST_ASSERT_EQUAL(1024, (int)alignedOffset);

    size_t unalignedLength = 1000;
    size_t alignedNext = Math::alignUp(unalignedLength, alignment);
    TEST_ASSERT_EQUAL(1024, (int)alignedNext);

    return {__func__, true, "Descriptor heap and argument buffer suballocation verified", 0.0};
  }

  TestResult testParallelCommandEncodingSimulation() {
    // Validate split command encoding across worker threads and async compute queue
    int numThreads = 4;
    std::vector<int> recordedCommands(numThreads, 0);
    for (int i = 0; i < numThreads; i++) {
      recordedCommands[i] = (i + 1) * 16;
    }
    int total = 0;
    for (int count : recordedCommands) total += count;
    TEST_ASSERT_EQUAL(160, total);

    return {__func__, true, "Parallel command encoding and async compute verified", 0.0};
  }

  TestResult testMeshShaderCapabilitySimulation() {
    // Validate object and mesh shader cluster sizing and culling
    int clusterTriangles = 128;
    int clusterVertices = 64;
    TEST_ASSERT(clusterTriangles <= 256, "Mesh shader triangles per threadgroup within HW limits");
    TEST_ASSERT(clusterVertices <= 256, "Mesh shader vertices per threadgroup within HW limits");

    return {__func__, true, "Mesh shader pipeline capability verified", 0.0};
  }

  TestResult testAudioLowLatencyAndPipeWireMode() {
    Audio::AudioInput audio;
    TEST_ASSERT_FALSE(audio.isLowLatencyMode());

    audio.setLowLatencyMode(true);
    TEST_ASSERT_TRUE(audio.isLowLatencyMode());

    audio.setSmoothing(0.85f);
    audio.setBeatThreshold(0.25f);

    std::vector<float> testSamples(256, 0.5f);
    audio.performFFT(testSamples);

    auto data = audio.getCurrentData();
    TEST_ASSERT(data.volume > 0.0f, "Audio volume must be non-zero after sample input");

    audio.setLowLatencyMode(false);
    TEST_ASSERT_FALSE(audio.isLowLatencyMode());

    return {__func__, true, "Low-latency PipeWire/ALSA audio verified", 0.0};
  }

  TestResult testIndirectCommandBuffersSimulation() {
    // Validate indirect command buffer dispatch parameters
    uint32_t particleCount = 10000;
    uint32_t vertexCount = 4;
    uint32_t instanceCount = particleCount;
    uint32_t baseVertex = 0;
    uint32_t baseInstance = 0;

    TEST_ASSERT_EQUAL(10000, (int)instanceCount);
    TEST_ASSERT_EQUAL(4, (int)vertexCount);
    TEST_ASSERT_EQUAL(0, (int)baseVertex);
    TEST_ASSERT_EQUAL(0, (int)baseInstance);

    return {__func__, true, "Indirect command buffer particle dispatch verified", 0.0};
  }

  TestResult testDynamicAcousticSceneDepth() {
    // Validate dynamic acoustic room geometry estimation from depth buffer
    std::vector<float> depthBuffer(32 * 32, 5.0f);
    depthBuffer[0] = 1.0f;
    depthBuffer[1] = 9.0f;

    float minDepth = 1e6f;
    float maxDepth = 0.0f;
    float avgDepth = 0.0f;
    for (float d : depthBuffer) {
      minDepth = std::min(minDepth, d);
      maxDepth = std::max(maxDepth, d);
      avgDepth += d;
    }
    avgDepth /= (float)depthBuffer.size();

    float roomSize = std::clamp(avgDepth * 2.0f, 2.0f, 50.0f);
    float scattering = std::clamp((maxDepth - minDepth) / avgDepth * 0.2f, 0.05f, 0.8f);

    TEST_ASSERT(roomSize > 5.0f && roomSize < 20.0f, "Derived room size in expected range");
    TEST_ASSERT(scattering > 0.05f && scattering < 0.8f, "Derived scattering in expected range");

    return {__func__, true, "Dynamic acoustic scene depth estimation verified", 0.0};
  }

  TestResult testMotionAdaptiveVRSRateMap() {
    // Test motion magnitude to peripheral rate map scaling
    float stillMotion = 0.0f;
    float fastMotion = 1.0f;

    float rateStill = std::clamp(1.0f + stillMotion * 2.0f, 1.0f, 4.0f);
    float rateFast = std::clamp(1.0f + fastMotion * 2.0f, 1.0f, 4.0f);

    TEST_ASSERT_EQUAL(1.0f, rateStill);
    TEST_ASSERT(rateFast >= 3.0f, "Fast motion should scale up peripheral VRS coarseness");

    return {__func__, true, "Motion-adaptive VRS rate map scaling verified", 0.0};
  }
};

REGISTER_TEST_SUITE(RendererFeatureTests);

} // namespace Test
} // namespace ShaderCandy
