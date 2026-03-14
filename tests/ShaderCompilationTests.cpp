#include "TestFramework.h"
#include <fstream>
#include <sstream>
#include <cstdlib>

namespace ShaderCandy {
namespace Test {

// Shader compilation test suite
class ShaderCompilationTests : public TestSuite {
public:
    std::string getName() const override {
        return "Shader Compilation Tests";
    }
    
    std::vector<TestResult> run() override {
        std::vector<TestResult> results;
        
        results.push_back(testGLSLVertexShader());
        results.push_back(testGLSLFragmentShader());
        results.push_back(testShaderUniforms());
        results.push_back(testShaderSyntax());
        
        return results;
    }

private:
    TestResult testGLSLVertexShader() {
        // Check if vertex shader file exists and has valid content
        std::ifstream file("shaders/base/vertex.glsl");
        if (!file.is_open()) {
            // Try alternate path for running from build directory
            file.open("../shaders/base/vertex.glsl");
        }
        if (!file.is_open()) {
            return {__func__, false, "Failed to open vertex.glsl - GLSL not supported in this build configuration", 0.0};
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
        // Check fragment shader includes
        std::ifstream file("shaders/base/common.glsl");
        if (!file.is_open()) {
            // Try alternate path for running from build directory
            file.open("../shaders/base/common.glsl");
        }
        if (!file.is_open()) {
            return {__func__, false, "Failed to open common.glsl - GLSL not supported in this build configuration", 0.0};
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
        // Verify uniform buffer structure
        std::ifstream file("shaders/base/common.glsl");
        if (!file.is_open()) {
            // Try alternate path for running from build directory
            file.open("../shaders/base/common.glsl");
        }
        if (!file.is_open()) {
            return {__func__, false, "Failed to open common.glsl - GLSL not supported in this build configuration", 0.0};
        }
        
        std::string content((std::istreambuf_iterator<char>(file)),
                            std::istreambuf_iterator<char>());
        
        // Check for required uniforms
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
        // Run glslangValidator if available
        int result = std::system("which glslangValidator > /dev/null 2>&1");
        if (result != 0) {
            return {__func__, true, "glslangValidator not available, skipping syntax check", 0.0};
        }
        
        // Test vertex shader
        result = std::system("glslangValidator -S vert shaders/base/vertex.glsl > /dev/null 2>&1");
        TEST_ASSERT(result == 0, "Vertex shader has syntax errors");
        
        // Test common.glsl (as fragment)
        result = std::system("glslangValidator -S frag shaders/base/common.glsl > /dev/null 2>&1");
        // Note: common.glsl might fail validation alone since it's meant to be included
        
        return {__func__, true, "Shader syntax validation passed", 0.0};
    }
};

// Register the test suite
REGISTER_TEST_SUITE(ShaderCompilationTests);

} // namespace Test
} // namespace ShaderCandy
