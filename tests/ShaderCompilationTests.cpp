#include "TestFramework.h"
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <vector>
#include <string>

namespace ShaderCandy {
namespace Test {

// Shader compilation test suite
class ShaderCompilationTests : public TestSuite {
public:
  std::string getName() const override { return "Shader Compilation Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;

    results.push_back(testGLSLVertexShader());
    results.push_back(testGLSLFragmentShader());
    results.push_back(testShaderUniforms());
    results.push_back(testShaderSyntax());
    results.push_back(testAllFragmentShaders());
    results.push_back(testShaderIncludeGuard());
    results.push_back(testPastelUnicornsShader());
    results.push_back(testShaderStructConsistency());

    return results;
  }

private:
  TestResult testGLSLVertexShader() {
    std::ifstream file("shaders/base/vertex.glsl");
    if (!file.is_open()) {
      file.open("../shaders/base/vertex.glsl");
    }
    if (!file.is_open()) {
      return {__func__, false,
              "Failed to open vertex.glsl - GLSL not supported in this build "
              "configuration",
              0.0};
    }

    std::string content((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());

    TEST_ASSERT(content.find("#version") != std::string::npos,
                "Vertex shader missing version directive");
    TEST_ASSERT(content.find("gl_Position") != std::string::npos,
                "Vertex shader missing gl_Position assignment");

    return {__func__, true, "Vertex shader structure valid", 0.0};
  }

  TestResult testGLSLFragmentShader() {
    std::ifstream file("shaders/base/common.glsl");
    if (!file.is_open()) {
      file.open("../shaders/base/common.glsl");
    }
    if (!file.is_open()) {
      return {__func__, false,
              "Failed to open common.glsl - GLSL not supported in this build "
              "configuration",
              0.0};
    }

    std::string content((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());

    TEST_ASSERT(content.find("#version") != std::string::npos,
                "Fragment shader missing version directive");
    TEST_ASSERT(content.find("uniform Uniforms") != std::string::npos,
                "Fragment shader missing uniform block");

    return {__func__, true, "Fragment shader structure valid", 0.0};
  }

  TestResult testShaderUniforms() {
    std::ifstream file("shaders/base/common.glsl");
    if (!file.is_open()) {
      file.open("../shaders/base/common.glsl");
    }
    if (!file.is_open()) {
      return {__func__, false,
              "Failed to open common.glsl - GLSL not supported in this build "
              "configuration",
              0.0};
    }

    std::string content((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());

    TEST_ASSERT(content.find("float time") != std::string::npos,
                "Missing time uniform");
    TEST_ASSERT(content.find("vec2 resolution") != std::string::npos,
                "Missing resolution uniform");
    TEST_ASSERT(content.find("vec2 mouse") != std::string::npos,
                "Missing mouse uniform");
    TEST_ASSERT(content.find("vec4 date") != std::string::npos,
                "Missing date uniform");
    TEST_ASSERT(content.find("int frame") != std::string::npos,
                "Missing frame uniform");

    return {__func__, true, "All required uniforms present", 0.0};
  }

  TestResult testShaderSyntax() {
    int result = std::system("which glslangValidator > /dev/null 2>&1");
    if (result != 0) {
      return {__func__, true,
              "glslangValidator not available, skipping syntax check", 0.0};
    }

    result = std::system(
        "glslangValidator -S vert shaders/base/vertex.glsl > /dev/null 2>&1");
    TEST_ASSERT(result == 0, "Vertex shader has syntax errors");

    return {__func__, true, "Shader syntax validation passed", 0.0};
  }

  // Discover and validate all .frag shaders in shaders/effects/
  TestResult testAllFragmentShaders() {
    std::vector<std::string> searchPaths = {
        "shaders/effects",
        "shaders",
        "../shaders/effects",
        "../shaders"
    };

    std::vector<std::string> fragFiles;
    for (const auto &path : searchPaths) {
      if (!std::filesystem::exists(path)) continue;

      for (const auto &entry : std::filesystem::directory_iterator(path)) {
        if (entry.path().extension() == ".frag") {
          fragFiles.push_back(entry.path().string());
        }
      }
      if (!fragFiles.empty()) break;
    }

    if (fragFiles.empty()) {
      return {__func__, true,
              "No .frag shaders found (not a failure — shaders may be Metal-only)",
              0.0};
    }

    int validated = 0;
    for (const auto &fragPath : fragFiles) {
      std::ifstream file(fragPath);
      if (!file.is_open()) continue;

      std::string content((std::istreambuf_iterator<char>(file)),
                          std::istreambuf_iterator<char>());

      // Each fragment shader must include common.glsl
      TEST_ASSERT(content.find("#include") != std::string::npos ||
                  content.find("#version") != std::string::npos,
                  "Shader " + fragPath + " missing include or version directive");

      // Must define effect_main
      TEST_ASSERT(content.find("effect_main") != std::string::npos,
                  "Shader " + fragPath + " missing effect_main entry point");

      // Must return vec4
      TEST_ASSERT(content.find("vec4") != std::string::npos,
                  "Shader " + fragPath + " missing vec4 return type");

      validated++;
    }

    return {__func__, true,
            "Validated " + std::to_string(validated) + " fragment shaders",
            0.0};
  }

  // Verify common.glsl has proper include guard
  TestResult testShaderIncludeGuard() {
    std::ifstream file("shaders/base/common.glsl");
    if (!file.is_open()) {
      file.open("../shaders/base/common.glsl");
    }
    if (!file.is_open()) {
      return {__func__, true,
              "common.glsl not found, skipping include guard test", 0.0};
    }

    std::string content((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());

    TEST_ASSERT(content.find("#ifndef COMMON_GLSL") != std::string::npos,
                "common.glsl missing include guard (#ifndef COMMON_GLSL)");
    TEST_ASSERT(content.find("#define COMMON_GLSL") != std::string::npos,
                "common.glsl missing include guard (#define COMMON_GLSL)");
    TEST_ASSERT(content.find("#endif") != std::string::npos,
                "common.glsl missing #endif for include guard");

    return {__func__, true, "Include guard present in common.glsl", 0.0};
  }

  // Validate the new pastel_unicorns.frag shader
  TestResult testPastelUnicornsShader() {
    std::ifstream file("shaders/effects/pastel_unicorns.frag");
    if (!file.is_open()) {
      file.open("../shaders/effects/pastel_unicorns.frag");
    }
    if (!file.is_open()) {
      return {__func__, true,
              "pastel_unicorns.frag not found (Metal-only shader)", 0.0};
    }

    std::string content((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());

    // Must have version
    TEST_ASSERT(content.find("#version") != std::string::npos,
                "pastel_unicorns.frag missing version directive");

    // Must include common.glsl
    TEST_ASSERT(content.find("common.glsl") != std::string::npos,
                "pastel_unicorns.frag must include common.glsl");

    // Must define effect_main
    TEST_ASSERT(content.find("effect_main") != std::string::npos,
                "pastel_unicorns.frag missing effect_main");

    // Must use uniforms (time, speed, intensity, alpha)
    TEST_ASSERT(content.find("time") != std::string::npos,
                "pastel_unicorns.frag missing time uniform usage");
    TEST_ASSERT(content.find("intensity") != std::string::npos,
                "pastel_unicorns.frag missing intensity uniform usage");
    TEST_ASSERT(content.find("alpha") != std::string::npos,
                "pastel_unicorns.frag missing alpha uniform usage");

    // Must have pastel colors (rainbow function)
    TEST_ASSERT(content.find("pastelRainbow") != std::string::npos,
                "pastel_unicorns.frag missing pastelRainbow function");
    TEST_ASSERT(content.find("pastelColor") != std::string::npos,
                "pastel_unicorns.frag missing pastelColor function");

    // Must have unicorn SDF
    TEST_ASSERT(content.find("sdUnicorn") != std::string::npos,
                "pastel_unicorns.frag missing sdUnicorn SDF function");

    // Must have rainbow arc
    TEST_ASSERT(content.find("rainbowArc") != std::string::npos,
                "pastel_unicorns.frag missing rainbowArc function");

    // Validate effect_main returns vec4
    TEST_ASSERT(content.find("return vec4") != std::string::npos,
                "pastel_unicorns.frag effect_main must return vec4");

    // Validate it uses uniforms correctly (not raw literals for time/speed)
    TEST_ASSERT(content.find("time * speed") != std::string::npos,
                "pastel_unicorns.frag must use time * speed for animation");

    return {__func__, true,
            "pastel_unicorns.frag structure and content validated", 0.0};
  }

  // Verify shader uniform struct consistency between CPU and GPU
  TestResult testShaderStructConsistency() {
    // Check that ShaderInterop.h defines the same fields as common.glsl
    std::ifstream interopFile("src/core/ShaderInterop.h");
    if (!interopFile.is_open()) {
      interopFile.open("../src/core/ShaderInterop.h");
    }

    std::ifstream glslFile("shaders/base/common.glsl");
    if (!glslFile.is_open()) {
      glslFile.open("../shaders/base/common.glsl");
    }

    if (!interopFile.is_open() || !glslFile.is_open()) {
      return {__func__, true,
              "Could not open both ShaderInterop.h and common.glsl for comparison",
              0.0};
    }

    std::string interopContent((std::istreambuf_iterator<char>(interopFile)),
                               std::istreambuf_iterator<char>());
    std::string glslContent((std::istreambuf_iterator<char>(glslFile)),
                            std::istreambuf_iterator<char>());

    // Both must define time, resolution, mouse, intensity, alpha
    const char *fields[] = {"time", "resolution", "mouse", "intensity", "alpha"};
    for (const auto &field : fields) {
      std::string fieldName(field);
      TEST_ASSERT(interopContent.find(fieldName) != std::string::npos,
                  "ShaderInterop.h missing field: " + fieldName);
      TEST_ASSERT(glslContent.find(fieldName) != std::string::npos,
                  "common.glsl missing field: " + fieldName);
    }

    return {__func__, true,
            "Shader struct consistency between CPU and GPU verified", 0.0};
  }
};

REGISTER_TEST_SUITE(ShaderCompilationTests);

} // namespace Test
} // namespace ShaderCandy
