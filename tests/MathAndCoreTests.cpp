#include "../src/core/MathUtils.h"
#include "../src/core/PerformanceMonitor.h"
#include "../src/core/UniformBuffer.h"
#include "TestFramework.h"
#include <cmath>
#include <thread>

namespace ShaderCandy {
namespace Test {

// Math and SIMD test suite
class MathTests : public TestSuite {
public:
  std::string getName() const override { return "Math & SIMD Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;

    results.push_back(testVectorOperations());
    results.push_back(testSIMDMultiplication());
    results.push_back(testSIMDSum());
    results.push_back(testSIMDLerp());
    results.push_back(testColorConversion());

    return results;
  }

private:
  TestResult testVectorOperations() {
    // Test Vec3
    Math::Vec3 a(1.0f, 2.0f, 3.0f);
    Math::Vec3 b(4.0f, 5.0f, 6.0f);

    // Test addition
    Math::Vec3 c = a + b;
    TEST_ASSERT_EQUAL(5.0f, c.x);
    TEST_ASSERT_EQUAL(7.0f, c.y);
    TEST_ASSERT_EQUAL(9.0f, c.z);

    // Test dot product
    float d = dot(a, b);
    TEST_ASSERT_EQUAL(32.0f, d); // 1*4 + 2*5 + 3*6 = 32

    // Test cross product
    Math::Vec3 e = cross(a, b);
    TEST_ASSERT_EQUAL(-3.0f, e.x); // 2*6 - 3*5 = -3
    TEST_ASSERT_EQUAL(6.0f, e.y);  // 3*4 - 1*6 = 6
    TEST_ASSERT_EQUAL(-3.0f, e.z); // 1*5 - 2*4 = -3

    // Test length
    float len = a.length();
    TEST_ASSERT(std::abs(len - std::sqrt(14.0f)) < 0.0001f,
                "Vector length incorrect");

    return {__func__, true, "Vector operations correct", 0.0};
  }

  TestResult testSIMDMultiplication() {
    const size_t count = 1024;
    std::vector<float> a(count), b(count), result(count);

    // Initialize test data
    for (size_t i = 0; i < count; i++) {
      a[i] = static_cast<float>(i);
      b[i] = static_cast<float>(count - i);
    }

    // Run SIMD multiplication
    Math::multiplyArray(result.data(), a.data(), b.data(), count);

    // Verify results
    for (size_t i = 0; i < count; i++) {
      float expected = a[i] * b[i];
      if (std::abs(result[i] - expected) > 0.0001f) {
        return {__func__, false,
                "SIMD multiplication failed at index " + std::to_string(i),
                0.0};
      }
    }

    return {__func__, true, "SIMD multiplication correct", 0.0};
  }

  TestResult testSIMDSum() {
    const size_t count = 1024;
    std::vector<float> data(count);

    // Initialize test data
    float expected = 0.0f;
    for (size_t i = 0; i < count; i++) {
      data[i] = static_cast<float>(i);
      expected += data[i];
    }

    // Run SIMD sum
    float result = Math::sumArray(data.data(), count);

    // Verify (with tolerance for floating point)
    if (std::abs(result - expected) > 0.1f) {
      return {__func__, false,
              "SIMD sum failed: expected " + std::to_string(expected) +
                  " got " + std::to_string(result),
              0.0};
    }

    return {__func__, true, "SIMD sum correct", 0.0};
  }

  TestResult testSIMDLerp() {
    const size_t count = 1024;
    std::vector<float> a(count), b(count), result(count);

    // Initialize test data
    for (size_t i = 0; i < count; i++) {
      a[i] = static_cast<float>(i);
      b[i] = static_cast<float>(i * 2);
    }

    float t = 0.5f;

    // Run SIMD lerp
    Math::lerpArray(result.data(), a.data(), b.data(), t, count);

    // Verify results
    for (size_t i = 0; i < count; i++) {
      float expected = a[i] * (1.0f - t) + b[i] * t;
      if (std::abs(result[i] - expected) > 0.0001f) {
        return {__func__, false,
                "SIMD lerp failed at index " + std::to_string(i), 0.0};
      }
    }

    return {__func__, true, "SIMD lerp correct", 0.0};
  }

  TestResult testColorConversion() {
    // Test HSV to RGB
    float hsv[3] = {0.0f, 1.0f, 1.0f}; // Red
    float rgb[3];

    Math::hsvToRgb(hsv, rgb);

    TEST_ASSERT(std::abs(rgb[0] - 1.0f) < 0.01f,
                "HSV->RGB red channel incorrect");
    TEST_ASSERT(std::abs(rgb[1] - 0.0f) < 0.01f,
                "HSV->RGB green channel incorrect");
    TEST_ASSERT(std::abs(rgb[2] - 0.0f) < 0.01f,
                "HSV->RGB blue channel incorrect");

    // Test RGB to HSV
    float rgb2[3] = {0.0f, 1.0f, 0.0f}; // Green
    float hsv2[3];

    Math::rgbToHsv(rgb2, hsv2);

    TEST_ASSERT(std::abs(hsv2[0] - 120.0f) < 1.0f, "RGB->HSV hue incorrect");
    TEST_ASSERT(std::abs(hsv2[1] - 1.0f) < 0.01f,
                "RGB->HSV saturation incorrect");
    TEST_ASSERT(std::abs(hsv2[2] - 1.0f) < 0.01f, "RGB->HSV value incorrect");

    return {__func__, true, "Color conversion correct", 0.0};
  }
};

// Register the test suite
REGISTER_TEST_SUITE(MathTests);

// Core functionality test suite
class CoreTests : public TestSuite {
public:
  std::string getName() const override { return "Core Functionality Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;

    results.push_back(testUniformBuffer());
    results.push_back(testPerformanceMonitor());

    return results;
  }

private:
  TestResult testUniformBuffer() {
    UniformBuffer buffer;
    buffer.initialize();

    // Test resolution update
    buffer.updateResolution(1920.0f, 1080.0f);
    const auto &data = buffer.getData();
    TEST_ASSERT_EQUAL(1920.0f, data.resolution[0]);
    TEST_ASSERT_EQUAL(1080.0f, data.resolution[1]);

    // Test mouse update
    buffer.updateMouse(0.5f, 0.5f);
    TEST_ASSERT_EQUAL(0.5f, data.mouse[0]);
    TEST_ASSERT_EQUAL(0.5f, data.mouse[1]);

    // Test frame advancement
    buffer.updateFrame(42);
    TEST_ASSERT_EQUAL(42, data.frame);

    return {__func__, true, "UniformBuffer works correctly", 0.0};
  }

  TestResult testPerformanceMonitor() {
    PerformanceMonitor monitor;

    // Simulate some frames
    for (int i = 0; i < 10; i++) {
      monitor.beginFrame();
      std::this_thread::sleep_for(std::chrono::milliseconds(16)); // ~60fps
      monitor.endFrame();
    }

    // Get metrics
    auto metrics = monitor.getMetrics();

    // Should have collected 10 frames
    TEST_ASSERT(metrics.averageFPS > 0, "FPS should be positive");
    TEST_ASSERT(metrics.frameTimeMs > 0, "Frame time should be positive");

    // Test reset
    monitor.reset();
    metrics = monitor.getMetrics();
    TEST_ASSERT_EQUAL(0.0f, metrics.averageFPS);

    return {__func__, true, "PerformanceMonitor works correctly", 0.0};
  }
};

// Register the test suite
REGISTER_TEST_SUITE(CoreTests);

} // namespace Test
} // namespace ShaderCandy
