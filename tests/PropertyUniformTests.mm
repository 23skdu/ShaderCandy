#include "../src/core/ShaderInterop.h"
#import "../src/metal/MetalRenderer.h"
#include "TestFramework.h"
#import <Metal/Metal.h>
#include <cmath>
#include <cstddef>
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
      id<MTLDevice> device = MTLCreateSystemDefaultDevice();
      if (!device) {
        results.push_back(
            {"Initialization", false, "Metal device not available for test", 0.0});
        return results;
      }

      NSError *error = nil;
      MetalRenderer *renderer = [MetalRenderer rendererWithDevice:device error:&error];
      if (!renderer || !renderer.resources || !renderer.resources.uniformBuffer) {
        results.push_back(
            {"Initialization", false,
             "MetalRenderer or uniform buffer not available for test", 0.0});
        return results;
      }

      // Verify device capability info (including VRS flag)
      results.push_back(
          {"Device Info", renderer.deviceInfo != nil,
           renderer.deviceInfo ? "MetalDeviceInfo populated" : "Missing deviceInfo",
           0.0});

      // Test Uniforms mapping for time, speed, intensity, gravity
      [renderer updateUniformsWithTime:12.5
                         mousePosition:NSMakePoint(400, 300)
                          mouseButtons:1
                                 speed:2.5f
                             intensity:1.3f
                               gravity:4.2f
                                height:600.0];

      results.push_back(checkUniformValue(
          "Time", renderer, offsetof(struct Uniforms, time), 12.5f));
      results.push_back(checkUniformValue(
          "Speed", renderer, offsetof(struct Uniforms, speed), 2.5f));
      results.push_back(checkUniformValue(
          "Intensity", renderer, offsetof(struct Uniforms, intensity), 1.3f));
      results.push_back(checkUniformValue(
          "Gravity", renderer, offsetof(struct Uniforms, gravity), 4.2f));
      results.push_back(checkUniformValue(
          "MouseButtons", renderer, offsetof(struct Uniforms, mouseButtons), 1.0f));

      [renderer shutdown];
    }

    return results;
  }

private:
  TestResult checkUniformValue(const std::string &name, MetalRenderer *renderer,
                               size_t offset, float expected) {
    uint8_t *contents = static_cast<uint8_t *>(renderer.resources.uniformBuffer.contents);
    float *actualPtr = reinterpret_cast<float *>(contents + offset);
    float actual = *actualPtr;

    bool passed = (std::fabs(actual - expected) < 0.001f);
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
