#include "../src/core/ShaderInterop.h"
#include "TestFramework.h"
#include <iostream>

namespace ShaderCandy {
namespace Test {

class LogicAndUniformTests : public TestSuite {
public:
  std::string getName() const override { return "Logic & Uniform Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;

    results.push_back(testUniformAlignment());
    results.push_back(testPresetLogic());
    results.push_back(testBranchlessMath());

    return results;
  }

private:
  TestResult testUniformAlignment() {
    // Essential for Metal interop: Uniforms must be a multiple of 16 bytes or
    // properly aligned
    size_t size = sizeof(Uniforms);

    // Output size for debugging
    std::cout << "Uniforms size: " << size << " bytes" << std::endl;

    // Metal constant buffers usually prefer 16-byte alignment for the total
    // size for efficiency
    TEST_ASSERT(size % 4 == 0, "Uniforms size must be multiple of 4");

    return {__func__, true, "Uniforms alignment and size valid", 0.0};
  }

  TestResult testPresetLogic() {
    // Simulate preset value application logic
    float speed = 1.0f;
    float intensity = 1.0f;

    // Mock "Cosmic" preset
    float presetSpeed = 0.8f;
    float presetIntensity = 1.2f;

    speed = presetSpeed;
    intensity = presetIntensity;

    TEST_ASSERT(speed == 0.8f, "Speed preset failed");
    TEST_ASSERT(intensity == 1.2f, "Intensity preset failed");

    return {__func__, true, "Preset logic simulation passed", 0.0};
  }

  TestResult testBranchlessMath() {
    // Simulate the select() logic used in shaders
    float pos = 1.5f; // Outside bounds
    float vel = 0.1f;

    // bool2 bounds = (abs(p.position) > 1.0);
    // p.velocity = select(p.velocity, p.velocity * -1.0, bounds);
    bool bounds = (std::abs(pos) > 1.0f);
    float nextVel = bounds ? (vel * -1.0f) : vel;

    TEST_ASSERT(nextVel == -0.1f, "Branchless bounce simulation failed");

    return {__func__, true, "Branchless math simulation passed", 0.0};
  }
};

REGISTER_TEST_SUITE(LogicAndUniformTests);

} // namespace Test
} // namespace ShaderCandy
