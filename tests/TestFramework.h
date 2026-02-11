#pragma once

#include <string>
#include <vector>
#include <functional>
#include <memory>

namespace ShaderCandy {
namespace Test {

// Test result structure
struct TestResult {
    std::string name;
    bool passed;
    std::string message;
    double durationMs;
};

// Test suite base class
class TestSuite {
public:
    virtual ~TestSuite() = default;
    virtual std::string getName() const = 0;
    virtual std::vector<TestResult> run() = 0;
};

// Main test framework
class TestFramework {
public:
    static TestFramework& getInstance();
    
    // Register a test suite
    void registerSuite(std::unique_ptr<TestSuite> suite);
    
    // Run all tests
    bool runAll();
    
    // Run specific test
    bool runTest(const std::string& name);
    
    // Get results
    const std::vector<TestResult>& getResults() const;
    
    // Print results
    void printResults() const;
    
    // Get summary
    int getPassCount() const;
    int getFailCount() const;

private:
    TestFramework() = default;
    std::vector<std::unique_ptr<TestSuite>> suites_;
    std::vector<TestResult> results_;
};

// Macro for registering tests
#define REGISTER_TEST_SUITE(SuiteClass) \
    static bool SuiteClass##_registered = []() { \
        ShaderCandy::Test::TestFramework::getInstance().registerSuite( \
            std::make_unique<SuiteClass>()); \
        return true; \
    }();

// Assertion helpers
#define TEST_ASSERT(condition, message) \
    if (!(condition)) { \
        return {__func__, false, message, 0.0}; \
    }

#define TEST_ASSERT_EQUAL(expected, actual) \
    if ((expected) != (actual)) { \
        return {__func__, false, "Expected " + std::to_string(expected) + \
                " but got " + std::to_string(actual), 0.0}; \
    }

#define TEST_ASSERT_TRUE(condition) \
    TEST_ASSERT(condition, "Expected true but got false")

#define TEST_ASSERT_FALSE(condition) \
    TEST_ASSERT(!(condition), "Expected false but got true")

#define TEST_ASSERT_NOT_NULL(ptr) \
    TEST_ASSERT((ptr) != nullptr, "Expected non-null pointer")

#define TEST_ASSERT_NULL(ptr) \
    TEST_ASSERT((ptr) == nullptr, "Expected null pointer")

} // namespace Test
} // namespace ShaderCandy
