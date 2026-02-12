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

    // Paths to search for shaders
    std::vector<std::string> shaderPaths = {"shaders", "shaders/base",
                                            "shaders/effects"};

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

    for (std::string dirPath : shaderPaths) {
      NSString *nsDirPath = [NSString stringWithUTF8String:dirPath.c_str()];
      BOOL isDir = NO;
      if (![fm fileExistsAtPath:nsDirPath isDirectory:&isDir] || !isDir) {
        dirPath = "../" + dirPath;
        nsDirPath = [NSString stringWithUTF8String:dirPath.c_str()];
        isDir = NO; // Reset for the new path
        if (![fm fileExistsAtPath:nsDirPath isDirectory:&isDir] || !isDir) {
          std::cout << "Skipping non-existent directory: " << dirPath
                    << std::endl;
          continue;
        }
      }

      std::cout << "Searching directory: " << dirPath << std::endl;

      NSArray *contents = [fm contentsOfDirectoryAtPath:nsDirPath error:nil];
      for (NSString *fileName in contents) {
        if ([fileName hasSuffix:@".metal"]) {
          if ([fileName isEqualToString:@"utils.metal"] ||
              [fileName isEqualToString:@"common.metal"])
            continue;

          std::cout << "  Found shader: " << [fileName UTF8String] << std::endl;
          NSString *fullPath =
              [nsDirPath stringByAppendingPathComponent:fileName];
          std::string shaderSource = loadFile([fullPath UTF8String]);

          if (shaderSource.empty()) {
            std::cout << "    Error: Failed to load source from "
                      << [fullPath UTF8String] << std::endl;
            continue;
          }

          // Strip redundant includes (mirror ShaderCandyView.mm)
          NSString *nsSource =
              [NSString stringWithUTF8String:shaderSource.c_str()];
          NSMutableString *msSource = [nsSource mutableCopy];
          NSArray *patterns = @[
            @"#include \"../core/ShaderInterop.h\"",
            @"#include \"ShaderInterop.h\"",
            @"#import \"../core/ShaderInterop.h\"",
            @"#import \"ShaderInterop.h\"", @"#include \"utils.metal\"",
            @"#include \"base/utils.metal\"",
            @"#include \"../base/utils.metal\""
          ];
          for (NSString *pattern in patterns) {
            [msSource
                replaceOccurrencesOfString:pattern
                                withString:@"// Stripped"
                                   options:0
                                     range:NSMakeRange(0, msSource.length)];
          }
          shaderSource = [msSource UTF8String];

          // Final shader source with interop and utils
          std::string fullSource = interopH + "\n" + vertexShader + "\n" +
                                   utilsMetal + "\n" + shaderSource;

          results.push_back(
              testCompile(device, [fileName UTF8String], fullSource));
        }
      }
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

      // Special cases for utility shaders like bloom.metal
      if (!frag && name == "bloom.metal") {
        frag = [library newFunctionWithName:@"bloom_threshold"];
      }

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
