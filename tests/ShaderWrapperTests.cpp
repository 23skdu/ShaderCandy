#include "TestFramework.h"
#include <fstream>
#include <sstream>
#include <iostream>
#include <regex>
#include <set>

namespace ShaderCandy {
namespace Test {

// Shader wrapper validation test suite
class ShaderWrapperTests : public TestSuite {
public:
    std::string getName() const override {
        return "Shader Wrapper Tests";
    }
    
    std::vector<TestResult> run() override {
        std::vector<TestResult> results;
        
        results.push_back(testNoDuplicateUniformBlocks());
        results.push_back(testCommonGLSLHasUniformBlock());
        results.push_back(testWrapperHasNoUniformBlock());
        results.push_back(testIncludeSystemNotDuplicatingUniforms());
        results.push_back(testShaderIncludeDepth());
        results.push_back(testValidFragmentShaderCompilation());
        
        return results;
    }

private:
    TestResult testNoDuplicateUniformBlocks() {
        // Read the screensaver.cpp to check the wrapper
        std::ifstream wrapperFile("src/platform/linux/screensaver.cpp");
        TEST_ASSERT(wrapperFile.is_open(), "Failed to open screensaver.cpp");
        
        std::string wrapperContent((std::istreambuf_iterator<char>(wrapperFile)),
                                   std::istreambuf_iterator<char>());
        
        // Find the wrappedFrag shader wrapper - this is where the issue was
        size_t wrappedFragStart = wrapperContent.find("wrappedFrag = R");
        size_t fallbackStart = wrapperContent.find("createFallbackShader");
        
        // Extract only the wrappedFrag section (before fallback)
        std::string wrappedSection;
        if (wrappedFragStart != std::string::npos && fallbackStart != std::string::npos) {
            wrappedSection = wrapperContent.substr(wrappedFragStart, fallbackStart - wrappedFragStart);
        }
        
        // Count occurrences of "uniform Uniforms" in the wrappedFrag section only
        std::regex uniformBlockRegex(R"(layout\s*\(\s*std140\s*\)\s*uniform\s+Uniforms\s*\{)");
        auto wrapperBegin = std::sregex_iterator(wrappedSection.begin(), 
                                                  wrappedSection.end(), 
                                                  uniformBlockRegex);
        auto wrapperEnd = std::sregex_iterator();
        
        int wrapperUniformBlocks = std::distance(wrapperBegin, wrapperEnd);
        
        // The wrapper's wrappedFrag should NOT have its own Uniforms block
        // (it should be defined only in common.glsl which shaders include)
        TEST_ASSERT(wrapperUniformBlocks == 0, 
                    "wrappedFrag defines its own Uniforms block - this will cause "
                    "duplicate declaration errors when shaders include common.glsl. "
                    "Remove the Uniforms block from wrappedFrag and let common.glsl provide it.");
        
        return {__func__, true, 
                "wrappedFrag correctly does not define Uniforms block - will be provided by common.glsl", 
                0.0};
    }
    
    TestResult testCommonGLSLHasUniformBlock() {
        // Verify common.glsl defines the Uniforms block
        std::ifstream commonFile("shaders/base/common.glsl");
        TEST_ASSERT(commonFile.is_open(), "Failed to open common.glsl");
        
        std::string commonContent((std::istreambuf_iterator<char>(commonFile)),
                                  std::istreambuf_iterator<char>());
        
        // Check that common.glsl defines the Uniforms block
        std::regex uniformBlockRegex(R"(layout\s*\(\s*std140\s*\)\s*uniform\s+Uniforms\s*\{)");
        TEST_ASSERT(std::regex_search(commonContent, uniformBlockRegex),
                    "common.glsl must define the Uniforms block since the wrapper no longer does");
        
        // Check for all required uniforms
        std::vector<std::string> requiredUniforms = {
            "float time", "float speed", "vec2 resolution", "vec2 mouse",
            "float mouseButtons", "float intensity", "vec4 date", "int frame",
            "float deltaTime", "float alpha", "float gravity"
        };
        
        for (const auto& uniform : requiredUniforms) {
            TEST_ASSERT(commonContent.find(uniform) != std::string::npos,
                        "Missing uniform in common.glsl: " + uniform);
        }
        
        return {__func__, true, 
                "common.glsl correctly defines all required uniforms in Uniforms block", 
                0.0};
    }
    
    TestResult testWrapperHasNoUniformBlock() {
        // This test specifically checks the wrappedFrag string in screensaver.cpp
        std::ifstream wrapperFile("src/platform/linux/screensaver.cpp");
        TEST_ASSERT(wrapperFile.is_open(), "Failed to open screensaver.cpp");
        
        std::string wrapperContent((std::istreambuf_iterator<char>(wrapperFile)),
                                   std::istreambuf_iterator<char>());
        
        // Find the wrappedFrag string - look for the shader wrapper code
        size_t wrappedFragStart = wrapperContent.find("wrappedFrag = R");
        TEST_ASSERT(wrappedFragStart != std::string::npos, 
                    "Could not find wrappedFrag definition");
        
        // Find the end of the wrapper fragment shader (before the closing paren-quote-semicolon)
        size_t wrapperEnd = wrapperContent.find(")\";", wrappedFragStart);
        TEST_ASSERT(wrapperEnd != std::string::npos,
                    "Could not find end of wrappedFrag definition");
        
        std::string wrappedFragContent = wrapperContent.substr(wrappedFragStart, 
                                                                wrapperEnd - wrappedFragStart);
        
        // The wrapper should NOT contain "layout(std140) uniform Uniforms"
        std::regex uniformBlockRegex(R"(layout\s*\(\s*std140\s*\)\s*uniform\s+Uniforms)");
        TEST_ASSERT(!std::regex_search(wrappedFragContent, uniformBlockRegex),
                    "wrappedFrag contains Uniforms block definition - "
                    "this will conflict with common.glsl. The wrapper should only "
                    "provide helper functions, not uniform declarations.");
        
        return {__func__, true, 
                "wrappedFrag correctly does not define Uniforms block", 
                0.0};
    }
    
    TestResult testIncludeSystemNotDuplicatingUniforms() {
        // Simulate the include processing to check for duplicates
        std::ifstream commonFile("shaders/base/common.glsl");
        TEST_ASSERT(commonFile.is_open(), "Failed to open common.glsl");
        
        std::string commonContent((std::istreambuf_iterator<char>(commonFile)),
                                  std::istreambuf_iterator<char>());
        
        // Count uniform declarations in common.glsl
        std::regex uniformVarRegex(R"(\b(float|vec2|vec4|int)\s+(time|speed|resolution|mouse|mouseButtons|intensity|date|frame|deltaTime|alpha|gravity)\b)");
        
        std::set<std::string> foundUniforms;
        auto begin = std::sregex_iterator(commonContent.begin(), commonContent.end(), uniformVarRegex);
        auto end = std::sregex_iterator();
        
        for (auto it = begin; it != end; ++it) {
            std::smatch match = *it;
            std::string uniformName = match[2].str();
            
            // Check for duplicates
            TEST_ASSERT(foundUniforms.find(uniformName) == foundUniforms.end(),
                        "Duplicate uniform declaration found in common.glsl: " + uniformName);
            foundUniforms.insert(uniformName);
        }
        
        // Verify we found all expected uniforms
        std::vector<std::string> expectedUniforms = {
            "time", "speed", "resolution", "mouse", "mouseButtons", 
            "intensity", "date", "frame", "deltaTime", "alpha", "gravity"
        };
        
        for (const auto& uniform : expectedUniforms) {
            TEST_ASSERT(foundUniforms.find(uniform) != foundUniforms.end(),
                        "Expected uniform not found in common.glsl: " + uniform);
        }
        
        return {__func__, true, 
                "No duplicate uniform declarations found, all expected uniforms present", 
                0.0};
    }
    
    TestResult testShaderIncludeDepth() {
        // Test that shaders don't create circular includes or excessive depth
        std::ifstream shaderFile("shaders/plasma.frag");
        TEST_ASSERT(shaderFile.is_open(), "Failed to open plasma.frag");
        
        std::string shaderContent((std::istreambuf_iterator<char>(shaderFile)),
                                  std::istreambuf_iterator<char>());
        
        // Check that the shader includes common.glsl
        TEST_ASSERT(shaderContent.find("#include \"base/common.glsl\"") != std::string::npos,
                    "plasma.frag should include base/common.glsl");
        
        // Verify common.glsl doesn't include other files (to avoid circular deps)
        std::ifstream commonFile("shaders/base/common.glsl");
        TEST_ASSERT(commonFile.is_open(), "Failed to open common.glsl");
        
        std::string commonContent((std::istreambuf_iterator<char>(commonFile)),
                                  std::istreambuf_iterator<char>());
        
        // common.glsl should not have any #include directives
        TEST_ASSERT(commonContent.find("#include") == std::string::npos,
                    "common.glsl should not have #include directives to avoid circular dependencies");
        
        return {__func__, true, 
                "Shader include structure is valid (no circular dependencies)", 
                0.0};
    }
    
    TestResult testValidFragmentShaderCompilation() {
        // Test that a shader can be properly assembled
        std::ifstream commonFile("shaders/base/common.glsl");
        TEST_ASSERT(commonFile.is_open(), "Failed to open common.glsl");
        
        std::string commonContent((std::istreambuf_iterator<char>(commonFile)),
                                  std::istreambuf_iterator<char>());
        
        std::ifstream plasmaFile("shaders/plasma.frag");
        TEST_ASSERT(plasmaFile.is_open(), "Failed to open plasma.frag");
        
        std::string plasmaContent((std::istreambuf_iterator<char>(plasmaFile)),
                                  std::istreambuf_iterator<char>());
        
        // Simulate the wrapper + include processing
        std::string assembledShader = R"(#version 330 core
in vec2 vTexCoord;
in vec2 vScreenPos;
out vec4 fragColor;

#define PI 3.14159265359
#define TWO_PI 6.28318530718
)";
        
        // Strip #version from common.glsl content
        std::string commonWithoutVersion = commonContent;
        size_t versionPos = commonWithoutVersion.find("#version");
        if (versionPos != std::string::npos) {
            size_t newlinePos = commonWithoutVersion.find('\n', versionPos);
            if (newlinePos != std::string::npos) {
                commonWithoutVersion = commonWithoutVersion.substr(0, versionPos) + 
                                       commonWithoutVersion.substr(newlinePos + 1);
            }
        }
        
        assembledShader += commonWithoutVersion;
        
        // Strip #include from plasma.frag and add its content
        std::string plasmaWithoutInclude = plasmaContent;
        size_t includePos = plasmaWithoutInclude.find("#include");
        if (includePos != std::string::npos) {
            size_t newlinePos = plasmaWithoutInclude.find('\n', includePos);
            if (newlinePos != std::string::npos) {
                plasmaWithoutInclude = plasmaWithoutInclude.substr(0, includePos) + 
                                       plasmaWithoutInclude.substr(newlinePos + 1);
            }
        }
        
        assembledShader += plasmaWithoutInclude;
        
        // Check for duplicate Uniforms block
        std::regex uniformBlockRegex(R"(layout\s*\(\s*std140\s*\)\s*uniform\s+Uniforms\s*\{)");
        auto begin = std::sregex_iterator(assembledShader.begin(), assembledShader.end(), uniformBlockRegex);
        auto end = std::sregex_iterator();
        
        int uniformBlockCount = std::distance(begin, end);
        TEST_ASSERT(uniformBlockCount == 1, 
                    "Assembled shader has " + std::to_string(uniformBlockCount) + 
                    " Uniforms block(s), expected exactly 1. "
                    "This causes: error: interface block `Uniforms' with type `uniform' already taken");
        
        // Check for duplicate uniform declarations
        std::vector<std::string> uniformsToCheck = {
            "float time", "float speed", "vec2 resolution", "vec2 mouse",
            "float mouseButtons", "float intensity", "vec4 date", "int frame",
            "float deltaTime", "float alpha", "float gravity"
        };
        
        for (const auto& uniform : uniformsToCheck) {
            size_t pos = 0;
            int count = 0;
            while ((pos = assembledShader.find(uniform, pos)) != std::string::npos) {
                // Make sure this is inside the Uniforms block, not elsewhere
                // Count occurrences
                count++;
                pos++;
            }
            TEST_ASSERT(count <= 1, 
                        "Duplicate declaration of '" + uniform + 
                        "' found (" + std::to_string(count) + " occurrences). "
                        "This causes: error: `'" + uniform.substr(uniform.find(' ') + 1) + 
                        "' redeclared");
        }
        
        return {__func__, true, 
                "Assembled shader has exactly 1 Uniforms block and no duplicate uniform declarations", 
                0.0};
    }
};

// Register the test suite
REGISTER_TEST_SUITE(ShaderWrapperTests);

} // namespace Test
} // namespace ShaderCandy
