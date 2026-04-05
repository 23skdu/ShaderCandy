#include "TestFramework.h"
#include <iostream>

using namespace ShaderCandy::Test;

int main() {
  std::cout << "Running Shader Wrapper Tests...\n" << std::endl;

  TestFramework &framework = TestFramework::getInstance();
  bool success = framework.runAll();
  framework.printResults();

  std::cout << "\n========================================" << std::endl;
  std::cout << "Total: " << framework.getPassCount() + framework.getFailCount()
            << " tests" << std::endl;
  std::cout << "Passed: " << framework.getPassCount() << std::endl;
  std::cout << "Failed: " << framework.getFailCount() << std::endl;
  std::cout << "========================================" << std::endl;

  return success ? 0 : 1;
}
