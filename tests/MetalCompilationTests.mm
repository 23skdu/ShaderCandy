#include "TestFramework.h"
#import <Metal/Metal.h>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace ShaderCandy {
namespace Test {

class MetalCompilationTests : public TestSuite {
public:
  std::string getName() const override { return "Metal Compilation Tests"; }

  std::vector<TestResult> run() override {
    std::vector<TestResult> results;

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
      results.push_back({"Initialization", false,
                         "Metal not supported on this hardware", 0.0});
      return results;
    }

    NSFileManager *fm = [NSFileManager defaultManager];

    // Load Interop and Utils
    std::string interopPath = "src/core/ShaderInterop.h";
    if (![fm fileExistsAtPath:[NSString
                                  stringWithUTF8String:interopPath.c_str()]]) {
      interopPath = "../" + interopPath;
    }
    std::string interopH = loadFile(interopPath);
    if (interopH.empty())
      std::cout << "Warning: Could not load ShaderInterop.h" << std::endl;

    std::string utilsPath = "shaders/base/utils.metal";
    if (![fm fileExistsAtPath:[NSString
                                  stringWithUTF8String:utilsPath.c_str()]]) {
      utilsPath = "../" + utilsPath;
    }
    std::string utilsMetal = loadFile(utilsPath);
    if (utilsMetal.empty())
      std::cout << "Warning: Could not load utils.metal" << std::endl;

    // Clean utils (mirror ShaderCandyView.mm)
    size_t pos;
    while ((pos = utilsMetal.find("#include <metal_stdlib>\n")) !=
           std::string::npos)
      utilsMetal.replace(pos, 24, "");
    while ((pos = utilsMetal.find("using namespace metal;\n")) !=
           std::string::npos)
      utilsMetal.replace(pos, 23, "");

    std::string vertexShader =
        "vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n"
        "    VertexOut out;\n"
        "    out.position = float4(in.position, 0.0, 1.0);\n"
        "    out.texCoord = in.texCoord;\n"
        "    return out;\n"
        "}\n";

    // Recursively search for shaders
    NSString *rootShadersPath = @"shaders";
    if (![fm fileExistsAtPath:rootShadersPath]) {
      rootShadersPath = @"../shaders";
    }

    std::cout << "Searching for shaders in: " << [rootShadersPath UTF8String]
              << std::endl;

    NSDirectoryEnumerator *enumerator =
        [fm enumeratorAtURL:[NSURL fileURLWithPath:rootShadersPath]
            includingPropertiesForKeys:@[ NSURLNameKey, NSURLIsDirectoryKey ]
                               options:NSDirectoryEnumerationSkipsHiddenFiles
                          errorHandler:nil];

    for (NSURL *fileURL in enumerator) {
      NSString *fileName = [fileURL lastPathComponent];
      if (![fileName hasSuffix:@".metal"])
        continue;

      // Skip utility/common files that are not standalone shaders
      if ([fileName isEqualToString:@"utils.metal"] ||
          [fileName isEqualToString:@"common.metal"] ||
          [fileName isEqualToString:@"ShaderInterop.h"])
        continue;

      std::string relativePath = [[fileURL path] UTF8String];
      std::cout << "  Found shader: " << relativePath << std::endl;

      std::string shaderSource = loadFile(relativePath);
      if (shaderSource.empty()) {
        results.push_back(
            {[fileName UTF8String], false, "Failed to load source file", 0.0});
        continue;
      }

      // Robustly strip includes using Regex (matching App logic)
      NSString *nsSource = [NSString stringWithUTF8String:shaderSource.c_str()];
      NSMutableString *msSource = [nsSource mutableCopy];

      NSRegularExpression *regex = [NSRegularExpression
          regularExpressionWithPattern:
              @"#\\s*include\\s+[\"<](?:\\.\\./)*(?:core/|base/"
              @")?(ShaderInterop\\.h|utils\\.metal)[\">]"
                               options:NSRegularExpressionCaseInsensitive
                                 error:nil];
      [regex replaceMatchesInString:msSource
                            options:0
                              range:NSMakeRange(0, msSource.length)
                       withTemplate:@""];

      shaderSource = [msSource UTF8String];

      // Final shader source construction (Interop -> Utils -> Vertex -> Source)
      std::string fullSource =
          "#include <metal_stdlib>\nusing namespace metal;\n\n" + interopH +
          "\n\n" + utilsMetal + "\n\n" + vertexShader + "\n\n" + shaderSource;

      results.push_back(testCompile(device, [fileName UTF8String], fullSource));
    }
    return results;
  }

private:
  std::string loadFile(const std::string &path) {
    std::ifstream file(path);
    if (!file.is_open())
      return "";
    return std::string((std::istreambuf_iterator<char>(file)),
                       std::istreambuf_iterator<char>());
  }

  TestResult testCompile(id<MTLDevice> device, const std::string &name,
                         const std::string &source) {
    @autoreleasepool {
      NSString *nsSource = [NSString stringWithUTF8String:source.c_str()];
      MTLCompileOptions *options = [[MTLCompileOptions alloc] init];

      NSError *error = nil;
      id<MTLLibrary> library = [device newLibraryWithSource:nsSource
                                                    options:options
                                                      error:&error];

      if (error) {
        std::string errorStr = [[error localizedDescription] UTF8String];
        return {name, false, "Compilation failed: " + errorStr, 0.0};
      }

      if (!library) {
        return {name, false, "Library creation returned nil without error",
                0.0};
      }

      // Verify entry points
      id<MTLFunction> vert = [library newFunctionWithName:@"vertex_main"];
      id<MTLFunction> frag = [library newFunctionWithName:@"fragment_main"];

      // Special cases for utility/compute shaders
      if (name == "bloom.metal" && !frag)
        frag = [library newFunctionWithName:@"bloom_threshold"];
      if (name == "neural_style_blend.metal")
        return {name, true, "Compiled successfully (Compute)", 0.0};
      if (name == "audio_ray_tracing.metal")
        return {name, true, "Compiled successfully (Compute)", 0.0};
      if (name == "reaction_diffusion.metal" && !frag)
        frag = [library newFunctionWithName:@"fragment_sim"];

      if (!vert)
        return {name, false, "Missing vertex_main", 0.0};
      if (!frag)
        return {name, false, "Missing fragment_main", 0.0};

      return {name, true, "Compiled successfully", 0.0};
    }
  }
};

REGISTER_TEST_SUITE(MetalCompilationTests);

} // namespace Test
} // namespace ShaderCandy
