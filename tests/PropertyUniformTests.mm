#include "../src/core/ShaderInterop.h"
#import "../src/platform/macos/ShaderCandyView.h"
#include "TestFramework.h"
#import <Metal/Metal.h>
#include <iostream>
#include <string>
#include <vector>

namespace ShaderCandy {
namespace Test {

class PropertyUniformTests : public TestSuite {
public:
  std::string getName() const override { return "Property Uniform Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;

    @autoreleasepool {
      NSRect frame = NSMakeRect(0, 0, 800, 600);
      ShaderCandyView *view = [[ShaderCandyView alloc] initWithFrame:frame
                                                           isPreview:NO];

      // Force initialization to create buffers
      [view setupMetal];

      // If setupMetal failed (no device), we can't test buffers
      if (!view.device || !view.uniformBuffer) {
        results.push_back(
            {"Initialization", false,
             "Metal device or uniform buffer not available for test", 0.0});
        return results;
      }

      // Test Speed
      view.speed = 2.5f;
      [view updateUniforms]; // Trigger render/uniform update
      results.push_back(checkUniformValue(
          "Speed", view, offsetof(struct Uniforms, speed), 2.5f));

      // Test Intensity
      view.intensity = 1.3f;
      view.frameCount++; // Simulate next frame
      [view updateUniforms];
      results.push_back(checkUniformValue(
          "Intensity", view, offsetof(struct Uniforms, intensity), 1.3f));

      // Test Gravity
      view.gravity = 4.2f;
      view.frameCount++;
      [view updateUniforms];
      results.push_back(checkUniformValue(
          "Gravity", view, offsetof(struct Uniforms, gravity), 4.2f));
    }

    return results;
  }

private:
  TestResult checkUniformValue(const std::string &name, ShaderCandyView *view,
                               size_t offset, float expected) {
    // Uniforms are triple buffered
    NSUInteger bufferIndex = (view.frameCount) % 3;
    uint8_t *contents = (uint8_t *)[view.uniformBuffer contents];
    float *actualPtr =
        (float *)(contents + bufferIndex * sizeof(struct Uniforms) + offset);
    float actual = *actualPtr;

    bool passed = (std::abs(actual - expected) < 0.001f);
    std::string msg = passed
                          ? "Correctly updated"
                          : "Mismatch: Expected " + std::to_string(expected) +
                                " but got " + std::to_string(actual);

    return {name + " property mapping", passed, msg, 0.0};
  }
};

REGISTER_TEST_SUITE(PropertyUniformTests);

} // namespace Test
} // namespace ShaderCandy
