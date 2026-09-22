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
    results.push_back(testSIMDScaleArray());
    results.push_back(testSIMDAddArray());
    results.push_back(testSIMDClampArray());
    results.push_back(testSIMDDotArray());
    results.push_back(testSIMDMinMaxArray());
    results.push_back(testSIMDFmaArray());
    results.push_back(testSIMDSumAbsArray());
    results.push_back(testSIMDVec4());
    results.push_back(testBatchColorConversion());

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

  TestResult testSIMDScaleArray() {
    const size_t count = 1024;
    std::vector<float> src(count), dst(count);
    for (size_t i = 0; i < count; i++) {
      src[i] = static_cast<float>(i) * 0.25f;
    }
    const float scale = 3.5f;
    Math::scaleArray(dst.data(), src.data(), scale, count);

    for (size_t i = 0; i < count; i++) {
      float expected = src[i] * scale;
      if (std::abs(dst[i] - expected) > 0.0001f) {
        return {__func__, false,
                "scaleArray failed at index " + std::to_string(i), 0.0};
      }
    }
    return {__func__, true, "scaleArray correct", 0.0};
  }

  TestResult testSIMDAddArray() {
    const size_t count = 1024;
    std::vector<float> a(count), b(count), dst(count);
    for (size_t i = 0; i < count; i++) {
      a[i] = static_cast<float>(i);
      b[i] = static_cast<float>(count - i) * 0.5f;
    }
    Math::addArray(dst.data(), a.data(), b.data(), count);

    for (size_t i = 0; i < count; i++) {
      float expected = a[i] + b[i];
      if (std::abs(dst[i] - expected) > 0.0001f) {
        return {__func__, false,
                "addArray failed at index " + std::to_string(i), 0.0};
      }
    }
    return {__func__, true, "addArray correct", 0.0};
  }

  TestResult testSIMDClampArray() {
    const size_t count = 1024;
    std::vector<float> src(count), dst(count);
    for (size_t i = 0; i < count; i++) {
      src[i] = static_cast<float>(i) - 500.0f; // -500 to 523
    }
    const float minVal = -100.0f;
    const float maxVal = 200.0f;
    Math::clampArray(dst.data(), src.data(), minVal, maxVal, count);

    for (size_t i = 0; i < count; i++) {
      float expected = std::max(minVal, std::min(maxVal, src[i]));
      if (std::abs(dst[i] - expected) > 0.0001f) {
        return {__func__, false,
                "clampArray failed at index " + std::to_string(i), 0.0};
      }
    }
    return {__func__, true, "clampArray correct", 0.0};
  }

  TestResult testSIMDDotArray() {
    const size_t count = 512;
    std::vector<float> a(count), b(count);
    double expected = 0.0;
    for (size_t i = 0; i < count; i++) {
      a[i] = static_cast<float>(i) * 0.01f;
      b[i] = (i % 2 == 0) ? 1.0f : -0.5f;
      expected += static_cast<double>(a[i] * b[i]);
    }
    float result = Math::dotArray(a.data(), b.data(), count);

    if (std::abs(result - static_cast<float>(expected)) > 0.05f) {
      return {__func__, false,
              "dotArray failed: expected " + std::to_string(expected) +
                  " got " + std::to_string(result),
              0.0};
    }
    return {__func__, true, "dotArray correct", 0.0};
  }

  TestResult testSIMDMinMaxArray() {
    const size_t count = 1024;
    std::vector<float> data(count);
    for (size_t i = 0; i < count; i++) {
      data[i] = static_cast<float>(i) * 1.5f - 100.0f;
    }
    // inject known extrema at arbitrary non-aligned indices
    data[7] = -999.0f;
    data[513] = 42000.0f;

    float outMin = 0.0f, outMax = 0.0f;
    Math::minMaxArray(data.data(), count, outMin, outMax);

    TEST_ASSERT_EQUAL(-999.0f, outMin);
    TEST_ASSERT_EQUAL(42000.0f, outMax);

    // Empty array edge case
    Math::minMaxArray(nullptr, 0, outMin, outMax);
    TEST_ASSERT_EQUAL(0.0f, outMin);
    TEST_ASSERT_EQUAL(0.0f, outMax);

    return {__func__, true, "minMaxArray correct", 0.0};
  }

  TestResult testSIMDFmaArray() {
    const size_t count = 1024;
    std::vector<float> a(count), b(count), c(count), dst(count);
    for (size_t i = 0; i < count; i++) {
      a[i] = static_cast<float>(i) * 0.1f;
      b[i] = 2.0f;
      c[i] = 5.0f;
    }
    Math::fmaArray(dst.data(), a.data(), b.data(), c.data(), count);

    for (size_t i = 0; i < count; i++) {
      float expected = a[i] * b[i] + c[i];
      if (std::abs(dst[i] - expected) > 0.001f) {
        return {__func__, false,
                "fmaArray failed at index " + std::to_string(i), 0.0};
      }
    }
    return {__func__, true, "fmaArray correct", 0.0};
  }

  TestResult testSIMDSumAbsArray() {
    const size_t count = 1024;
    std::vector<float> data(count);
    float expected = 0.0f;
    for (size_t i = 0; i < count; i++) {
      float val = (i % 2 == 0) ? static_cast<float>(i) : -static_cast<float>(i);
      data[i] = val;
      expected += std::abs(val);
    }
    float result = Math::sumAbsArray(data.data(), count);

    if (std::abs(result - expected) > 0.1f) {
      return {__func__, false,
              "sumAbsArray failed: expected " + std::to_string(expected) +
                  " got " + std::to_string(result),
              0.0};
    }
    return {__func__, true, "sumAbsArray correct", 0.0};
  }

  TestResult testSIMDVec4() {
    Math::Vec4 a(1.0f, 2.0f, 3.0f, 4.0f);
    Math::Vec4 b(5.0f, 6.0f, 7.0f, 8.0f);

    // Addition
    Math::Vec4 c = a + b;
    TEST_ASSERT_EQUAL(6.0f, c.x);
    TEST_ASSERT_EQUAL(8.0f, c.y);
    TEST_ASSERT_EQUAL(10.0f, c.z);
    TEST_ASSERT_EQUAL(12.0f, c.w);

    // Subtraction
    Math::Vec4 sub = b - a;
    TEST_ASSERT_EQUAL(4.0f, sub.x);
    TEST_ASSERT_EQUAL(4.0f, sub.y);
    TEST_ASSERT_EQUAL(4.0f, sub.z);
    TEST_ASSERT_EQUAL(4.0f, sub.w);

    // Scalar & Vector multiplication
    Math::Vec4 mulScalar = a * 2.0f;
    TEST_ASSERT_EQUAL(2.0f, mulScalar.x);
    TEST_ASSERT_EQUAL(4.0f, mulScalar.y);
    TEST_ASSERT_EQUAL(6.0f, mulScalar.z);
    TEST_ASSERT_EQUAL(8.0f, mulScalar.w);

    Math::Vec4 mulVec = a * b;
    TEST_ASSERT_EQUAL(5.0f, mulVec.x);
    TEST_ASSERT_EQUAL(12.0f, mulVec.y);
    TEST_ASSERT_EQUAL(21.0f, mulVec.z);
    TEST_ASSERT_EQUAL(32.0f, mulVec.w);

    // Division
    Math::Vec4 divScalar = b / 2.0f;
    TEST_ASSERT_EQUAL(2.5f, divScalar.x);

    // Dot product
    // 1*5 + 2*6 + 3*7 + 4*8 = 5 + 12 + 21 + 32 = 70
    float d = Math::dot(a, b);
    TEST_ASSERT_EQUAL(70.0f, d);

    // Length and normalization
    Math::Vec4 v(0.0f, 3.0f, 4.0f, 0.0f);
    TEST_ASSERT_EQUAL(25.0f, v.lengthSq());
    TEST_ASSERT_EQUAL(5.0f, v.length());

    Math::Vec4 vn = v.normalize();
    TEST_ASSERT(std::abs(vn.length() - 1.0f) < 0.0001f, "Vec4 normalize failed");
    TEST_ASSERT_EQUAL(0.6f, vn.y);
    TEST_ASSERT_EQUAL(0.8f, vn.z);

    // Clamping & Mix
    Math::Vec4 clamped = Math::clamp(Math::Vec4(-1.0f, 0.5f, 2.0f, 10.0f), 0.0f, 1.0f);
    TEST_ASSERT_EQUAL(0.0f, clamped.x);
    TEST_ASSERT_EQUAL(0.5f, clamped.y);
    TEST_ASSERT_EQUAL(1.0f, clamped.z);
    TEST_ASSERT_EQUAL(1.0f, clamped.w);

    Math::Vec4 mixed = Math::mix(a, b, 0.5f);
    TEST_ASSERT_EQUAL(3.0f, mixed.x);
    TEST_ASSERT_EQUAL(4.0f, mixed.y);
    TEST_ASSERT_EQUAL(5.0f, mixed.z);
    TEST_ASSERT_EQUAL(6.0f, mixed.w);

    // Equality
    Math::Vec4 aCopy = a;
    TEST_ASSERT(a == aCopy, "Vec4 equality failed");
    TEST_ASSERT(a != b, "Vec4 inequality failed");

    return {__func__, true, "Vec4 operations correct", 0.0};
  }

  TestResult testBatchColorConversion() {
    const size_t numPixels = 64;
    std::vector<float> rgb(numPixels * 3);
    std::vector<float> hsv(numPixels * 3);
    std::vector<float> roundTrip(numPixels * 3);

    // Create varied color palette
    for (size_t i = 0; i < numPixels; i++) {
      rgb[i * 3 + 0] = static_cast<float>(i) / static_cast<float>(numPixels);
      rgb[i * 3 + 1] = 1.0f - (static_cast<float>(i) / static_cast<float>(numPixels));
      rgb[i * 3 + 2] = (i % 2 == 0) ? 0.8f : 0.2f;
    }

    Math::batchRgbToHsv(rgb.data(), hsv.data(), numPixels);
    Math::batchHsvToRgb(hsv.data(), roundTrip.data(), numPixels);

    for (size_t i = 0; i < numPixels * 3; i++) {
      if (std::abs(rgb[i] - roundTrip[i]) > 0.03f) {
        return {__func__, false,
                "Batch color round-trip mismatch at element " + std::to_string(i),
                0.0};
      }
    }

    return {__func__, true, "Batch color conversion correct", 0.0};
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
