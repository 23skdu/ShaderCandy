#include "TestFramework.h"
#include <cstring>
#include <iostream>

// Include test files to ensure they're compiled and registered
#include "LogicAndUniformTests.cpp"
#include "MathAndCoreTests.cpp"
#include "ShaderCompilationTests.cpp"
#ifdef __APPLE__
#include "MetalCompilationTests.mm"
#include "PropertyUniformTests.mm"
#endif

using namespace ShaderCandy::Test;

void printUsage(const char *program) {
  std::cout << "Usage: " << program << " [options]\n\n";
  std::cout << "Options:\n";
  std::cout << "  --list       List all available test suites\n";
  std::cout << "  --run <name> Run specific test suite\n";
  std::cout << "  --help       Show this help message\n";
  std::cout << "  (no args)    Run all tests\n";
}

void listTests() {
  std::cout << "Available test suites:\n";
  std::cout << "======================\n\n";

  // The test suites are auto-registered when their .cpp files are included
  // We can't easily list them without running, so just document them
  std::cout << "1. Shader Compilation Tests\n";
  std::cout << "   - GLSL vertex shader validation\n";
  std::cout << "   - GLSL fragment shader validation\n";
  std::cout << "   - Uniform buffer structure tests\n";
  std::cout << "   - Syntax validation (requires glslangValidator)\n\n";

  std::cout << "2. Math & SIMD Tests\n";
  std::cout << "   - Vector operations (add, dot, cross, length)\n";
  std::cout << "   - SIMD multiplication\n";
  std::cout << "   - SIMD sum reduction\n";
  std::cout << "   - SIMD linear interpolation\n";
  std::cout << "   - Color space conversion (RGB/HSV)\n\n";

  std::cout << "3. Core Functionality Tests\n";
  std::cout << "   - Uniform buffer management\n";
  std::cout << "   - Performance monitoring\n\n";
}

int main(int argc, char **argv) {
  if (argc > 1) {
    if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
      printUsage(argv[0]);
      return 0;
    }

    if (strcmp(argv[1], "--list") == 0 || strcmp(argv[1], "-l") == 0) {
      listTests();
      return 0;
    }

    if (strcmp(argv[1], "--run") == 0) {
      if (argc < 3) {
        std::cerr << "Error: --run requires a test suite name\n";
        return 1;
      }

      TestFramework &framework = TestFramework::getInstance();
      bool success = framework.runTest(argv[2]);

      if (success) {
        framework.printResults();
        return framework.getFailCount() == 0 ? 0 : 1;
      } else {
        return 1;
      }
    }

    std::cerr << "Unknown option: " << argv[1] << "\n";
    printUsage(argv[0]);
    return 1;
  }

  // Run all tests
  TestFramework &framework = TestFramework::getInstance();
  bool success = framework.runAll();

  return success ? 0 : 1;
}
