#include "TestFramework.h"
#include <chrono>
#include <iomanip>
#include <iostream>

namespace ShaderCandy {
namespace Test {

// Singleton implementation
TestFramework &TestFramework::getInstance() {
  static TestFramework instance;
  return instance;
}

void TestFramework::registerSuite(std::unique_ptr<TestSuite> suite) {
  suites_.push_back(std::move(suite));
}

bool TestFramework::runAll() {
  results_.clear();

  std::cout << "\n========================================\n";
  std::cout << "ShaderCandy Test Framework\n";
  std::cout << "========================================\n\n";

  for (auto &suite : suites_) {
    std::cout << "Running: " << suite->getName() << "\n";
    std::cout << std::string(suite->getName().length() + 9, '-') << "\n";

    auto suiteResults = suite->run();
    results_.insert(results_.end(), suiteResults.begin(), suiteResults.end());
  }

  printResults();

  return getFailCount() == 0;
}

bool TestFramework::runTest(const std::string &name) {
  results_.clear();

  for (auto &suite : suites_) {
    if (suite->getName() == name) {
      auto suiteResults = suite->run();
      results_.insert(results_.end(), suiteResults.begin(), suiteResults.end());
      return true;
    }
  }

  std::cerr << "Test suite not found: " << name << "\n";
  return false;
}

const std::vector<TestResult> &TestFramework::getResults() const {
  return results_;
}

void TestFramework::printResults() const {
  std::cout << "\n========================================\n";
  std::cout << "Test Results\n";
  std::cout << "========================================\n\n";

  int passCount = 0;
  int failCount = 0;

  for (const auto &result : results_) {
    std::cout << (result.passed ? "[PASS] " : "[FAIL] ") << std::left
              << std::setw(50) << result.name << " " << result.message;

    if (result.durationMs > 0) {
      std::cout << " (" << std::fixed << std::setprecision(2)
                << result.durationMs << "ms)";
    }
    std::cout << "\n";

    if (result.passed) {
      passCount++;
    } else {
      failCount++;
    }
  }

  std::cout << "\n========================================\n";
  std::cout << "Summary: " << passCount << " passed, " << failCount
            << " failed\n";
  std::cout << "========================================\n";
}

int TestFramework::getPassCount() const {
  int count = 0;
  for (const auto &result : results_) {
    if (result.passed)
      count++;
  }
  return count;
}

int TestFramework::getFailCount() const {
  int count = 0;
  for (const auto &result : results_) {
    if (!result.passed)
      count++;
  }
  return count;
}

} // namespace Test
} // namespace ShaderCandy
