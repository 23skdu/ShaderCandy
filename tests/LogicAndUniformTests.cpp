#include "../src/config/PresetManager.h"
#include "../src/core/MathUtils.h"
#include "../src/core/ShaderInterop.h"
#include "TestFramework.h"
#include <iostream>
#include <limits>

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
    using namespace ShaderCandy::Config;

    Preset preset("cosmic");
    preset.name = "Cosmic";
    preset.author = "ShaderCandy";
    preset.description = "Deep space cosmic nebula with stars";
    preset.version = "1.0";
    preset.setFloat("speed", 0.8f);
    preset.setFloat("intensity", 1.2f);
    preset.setBool("bloom", true);
    preset.setInt("palette", 3);

    TEST_ASSERT(preset.getFloat("speed") == 0.8f, "Speed preset parameter mismatch");
    TEST_ASSERT(preset.getFloat("intensity") == 1.2f, "Intensity preset parameter mismatch");
    TEST_ASSERT_TRUE(preset.getBool("bloom"));
    TEST_ASSERT_EQUAL(3, preset.getInt("palette"));

    // Verify preset validation
    auto &manager = PresetManager::getInstance();
    auto valErr = manager.validatePreset(preset);
    TEST_ASSERT_TRUE(valErr == PresetValidationError::None);

    // Verify invalid parameter validation
    Preset badPreset = preset;
    badPreset.setFloat("", 1.0f);
    TEST_ASSERT_TRUE(manager.validatePreset(badPreset) == PresetValidationError::InvalidParameters);

    // Verify dictionary serialization and deserialization roundtrip
    auto dict = preset.toDictionary();
    Preset deserialized = Preset::fromDictionary(dict);
    TEST_ASSERT(deserialized.name == "Cosmic", "Deserialized name mismatch");
    TEST_ASSERT(deserialized.shaderName == "cosmic", "Deserialized shaderName mismatch");
    TEST_ASSERT(deserialized.getFloat("speed") == 0.8f, "Deserialized speed mismatch");
    TEST_ASSERT(deserialized.getFloat("intensity") == 1.2f, "Deserialized intensity mismatch");

    return {__func__, true, "Preset logic and validation passed", 0.0};
  }

  TestResult testBranchlessMath() {
    // Test branchless bounce and selection logic with first-class MathUtils methods
    float pos = 1.5f; // Outside bounds
    float vel = 0.1f;

    float nextVel = Math::branchlessBounce(pos, vel, -1.0f, 1.0f);
    TEST_ASSERT(nextVel == -0.1f, "Branchless bounce failed");

    float selected = Math::branchlessSelect(true, 42.0f, 0.0f);
    TEST_ASSERT_EQUAL(42.0f, selected);
    float unselected = Math::branchlessSelect(false, 42.0f, 0.0f);
    TEST_ASSERT_EQUAL(0.0f, unselected);

    // Test graphics math primitives
    TEST_ASSERT_EQUAL(0.5f, Math::clamp(0.5f, 0.0f, 1.0f));
    TEST_ASSERT_EQUAL(1.0f, Math::clamp(2.5f, 0.0f, 1.0f));
    TEST_ASSERT_EQUAL(15.0f, Math::mix(10.0f, 20.0f, 0.5f));
    TEST_ASSERT_EQUAL(0.5f, Math::smoothstep(0.0f, 1.0f, 0.5f));

    // Test Math::Vec2 and Math::Vec3 operators
    Math::Vec2 v2a(3.0f, 4.0f);
    TEST_ASSERT_EQUAL(5.0f, v2a.length());
    Math::Vec2 v2b = v2a.normalize();
    TEST_ASSERT(std::abs(v2b.length() - 1.0f) < 0.001f, "Vec2 normalization failed");
    TEST_ASSERT_EQUAL(25.0f, Math::dot(v2a, v2a));

    // Test Math::lerpArray with SIMD/scalar dispatch
    float aArr[4] = {0.0f, 10.0f, 20.0f, 30.0f};
    float bArr[4] = {10.0f, 20.0f, 30.0f, 40.0f};
    float dstArr[4] = {0};
    Math::lerpArray(dstArr, aArr, bArr, 0.5f, 4);
    TEST_ASSERT_EQUAL(5.0f, dstArr[0]);
    TEST_ASSERT_EQUAL(15.0f, dstArr[1]);
    TEST_ASSERT_EQUAL(25.0f, dstArr[2]);
    TEST_ASSERT_EQUAL(35.0f, dstArr[3]);

    Math::Vec3 normal(0.0f, 1.0f, 0.0f);
    Math::Vec3 incident(1.0f, -1.0f, 0.0f);
    Math::Vec3 reflected = Math::reflect(incident, normal);
    TEST_ASSERT_EQUAL(1.0f, reflected.x);
    TEST_ASSERT_EQUAL(1.0f, reflected.y);
    TEST_ASSERT_EQUAL(0.0f, reflected.z);

    return {__func__, true, "Branchless math and vector reflection passed", 0.0};
  }
};

REGISTER_TEST_SUITE(LogicAndUniformTests);

} // namespace Test
} // namespace ShaderCandy
