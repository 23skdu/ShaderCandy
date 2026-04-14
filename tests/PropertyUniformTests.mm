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
      if (!view.renderer.device || !view.renderer.uniformBuffer) {
        results.push_back(
            {"Initialization", false,
             "Metal device or uniform buffer not available for test", 0.0});
        return results;
      }

      // Test Shader Discovery
      NSArray *shaders = view.availableShaders;
      NSArray *expected = @[
        @"mandelbulb_3d", @"julia_3d", @"julia_set", @"mandelbrot_set",
        @"flying_toasters", @"voronoi_cells", @"tunnel", @"plasma", @"ripples"
      ];

      bool shadersPass = true;
      std::string missingShaders = "";
      for (NSString *name in expected) {
        if (![shaders containsObject:name]) {
          shadersPass = false;
          missingShaders += [name UTF8String];
          missingShaders += " ";
        }
      }
      results.push_back({"Shader Discovery", shadersPass,
                         shadersPass ? "All expected shaders found"
                                     : "Missing: " + missingShaders,
                         0.0});

      // Test Speed
      view.speed = 2.5f;
      [view.renderer updateUniformsWithTime:0.0];
      results.push_back(checkUniformValue(
          "Speed", view, offsetof(struct Uniforms, speed), 2.5f));

      // Test Intensity
      view.intensity = 1.3f;
      view.renderer.frameCount++; // Simulate next frame
      [view.renderer updateUniformsWithTime:0.0];
      results.push_back(checkUniformValue(
          "Intensity", view, offsetof(struct Uniforms, intensity), 1.3f));

      // Test Gravity
      view.gravity = 4.2f;
      view.renderer.frameCount++;
      [view.renderer updateUniformsWithTime:0.0];
      results.push_back(checkUniformValue(
          "Gravity", view, offsetof(struct Uniforms, gravity), 4.2f));
    }

    return results;
  }

private:
  TestResult checkUniformValue(const std::string &name, ShaderCandyView *view,
                               size_t offset, float expected) {
    // Uniforms are triple buffered
    NSUInteger bufferIndex = (view.renderer.frameCount) % 3;
    uint8_t *contents = (uint8_t *)[view.renderer.uniformBuffer contents];
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
