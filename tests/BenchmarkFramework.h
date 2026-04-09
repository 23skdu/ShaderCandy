#pragma once

#include <string>
#include <vector>
#include <functional>
#include <chrono>
#include <memory>
#include <algorithm>
#include <cmath>

namespace ShaderCandy {
namespace Benchmark {

// Benchmark result structure
struct BenchmarkResult {
    std::string name;
    double durationMs;          // Total duration
    double averageMs;           // Average per iteration
    double minMs;               // Minimum iteration time
    double maxMs;               // Maximum iteration time
    double stdDev;              // Standard deviation
    size_t iterations;          // Number of iterations
    size_t operations;          // Number of operations performed
    double opsPerSecond;        // Operations per second
    
    // Calculate throughput if operations > 0
    double getThroughput() const {
        if (operations == 0) return 0.0;
        return (operations / durationMs) * 1000.0; // ops/sec
    }
};

// Benchmark suite base class
class BenchmarkSuite {
public:
    virtual ~BenchmarkSuite() = default;
    virtual std::string getName() const = 0;
    virtual std::vector<BenchmarkResult> run() = 0;
};

// Benchmark framework with statistical analysis
class BenchmarkFramework {
public:
    static BenchmarkFramework& getInstance() {
        static BenchmarkFramework instance;
        return instance;
    }
    
    // Register a benchmark suite
    void registerSuite(std::unique_ptr<BenchmarkSuite> suite) {
        suites_.push_back(std::move(suite));
    }
    
    // Run all benchmarks
    bool runAll() {
        results_.clear();
        for (auto& suite : suites_) {
            auto suiteResults = suite->run();
            results_.insert(results_.end(), suiteResults.begin(), suiteResults.end());
        }
        return !results_.empty();
    }
    
    // Run specific benchmark suite
    bool runSuite(const std::string& name) {
        for (auto& suite : suites_) {
            if (suite->getName() == name) {
                auto suiteResults = suite->run();
                results_.insert(results_.end(), suiteResults.begin(), suiteResults.end());
                return true;
            }
        }
        return false;
    }
    
    // Get results
    const std::vector<BenchmarkResult>& getResults() const {
        return results_;
    }
    
    // Print results in a formatted table
    void printResults() const {
        if (results_.empty()) {
            printf("No benchmark results.\n");
            return;
        }
        
        printf("\n=== Benchmark Results ===\n");
        printf("%-40s %12s %12s %12s %12s\n", 
               "Benchmark", "Avg (ms)", "Min (ms)", "Max (ms)", "StdDev");
        printf("--------------------------------------------------------------------------\n");
        
        for (const auto& result : results_) {
            printf("%-40s %12.4f %12.4f %12.4f %12.4f\n",
                   result.name.c_str(),
                   result.averageMs,
                   result.minMs,
                   result.maxMs,
                   result.stdDev);
        }
        
        printf("\n");
    }
    
    // Print throughput results
    void printThroughputResults() const {
        if (results_.empty()) {
            printf("No benchmark results.\n");
            return;
        }
        
        printf("\n=== Throughput Results ===\n");
        printf("%-40s %15s %15s\n", 
               "Benchmark", "Ops/Second", "Total Ops");
        printf("--------------------------------------------------------------------------\n");
        
        for (const auto& result : results_) {
            if (result.operations > 0) {
                printf("%-40s %15.0f %15zu\n",
                       result.name.c_str(),
                       result.getThroughput(),
                       result.operations);
            }
        }
        
        printf("\n");
    }
    
    // Export results to JSON file
    void exportToJson(const std::string& filepath) {
        // Implementation for JSON export
        // Could be expanded to include timestamps, git commit, etc.
    }
    
    // Get summary statistics
    struct Summary {
        size_t totalBenchmarks;
        double totalDurationMs;
        double fastestBenchmark;
        double slowestBenchmark;
    };
    
    Summary getSummary() const {
        Summary summary;
        summary.totalBenchmarks = results_.size();
        summary.totalDurationMs = 0.0;
        summary.fastestBenchmark = std::numeric_limits<double>::max();
        summary.slowestBenchmark = 0.0;
        
        for (const auto& result : results_) {
            summary.totalDurationMs += result.durationMs;
            summary.fastestBenchmark = std::min(summary.fastestBenchmark, result.averageMs);
            summary.slowestBenchmark = std::max(summary.slowestBenchmark, result.averageMs);
        }
        
        return summary;
    }
    
    // Compare against baseline (for regression detection)
    struct RegressionResult {
        std::string benchmarkName;
        double baselineMs;
        double currentMs;
        double percentChange;
        bool isRegression;
        bool isImprovement;
    };
    
    std::vector<RegressionResult> compareAgainstBaseline(
        const std::vector<BenchmarkResult>& baseline) {
        
        std::vector<RegressionResult> regressions;
        
        for (const auto& current : results_) {
            for (const auto& base : baseline) {
                if (current.name == base.name) {
                    double change = ((current.averageMs - base.averageMs) / base.averageMs) * 100.0;
                    
                    RegressionResult reg;
                    reg.benchmarkName = current.name;
                    reg.baselineMs = base.averageMs;
                    reg.currentMs = current.averageMs;
                    reg.percentChange = change;
                    reg.isRegression = change > 10.0;  // 10% threshold
                    reg.isImprovement = change < -10.0; // -10% threshold
                    
                    regressions.push_back(reg);
                    break;
                }
            }
        }
        
        return regressions;
    }
    
private:
    BenchmarkFramework() = default;
    std::vector<std::unique_ptr<BenchmarkSuite>> suites_;
    std::vector<BenchmarkResult> results_;
};

// Macro for registering benchmark suites
#define REGISTER_BENCHMARK_SUITE(SuiteClass) \
    static bool SuiteClass##_registered = []() { \
        ShaderCandy::Benchmark::BenchmarkFramework::getInstance().registerSuite( \
            std::make_unique<SuiteClass>()); \
        return true; \
    }();

// Helper class for timing iterations
class Timer {
public:
    Timer() : start_(std::chrono::high_resolution_clock::now()) {}
    
    double elapsedMs() const {
        auto end = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double, std::milli> duration = end - start_;
        return duration.count();
    }
    
    void reset() {
        start_ = std::chrono::high_resolution_clock::now();
    }
    
private:
    std::chrono::high_resolution_clock::time_point start_;
};

// Benchmark runner with statistical analysis
template<typename Func>
BenchmarkResult runBenchmark(const std::string& name, Func func, 
                             size_t iterations = 1000, size_t operations = 0) {
    std::vector<double> times;
    times.reserve(iterations);
    
    Timer totalTimer;
    
    for (size_t i = 0; i < iterations; i++) {
        Timer iterationTimer;
        func();
        times.push_back(iterationTimer.elapsedMs());
    }
    
    double totalDuration = totalTimer.elapsedMs();
    
    // Calculate statistics
    double sum = 0.0;
    double min = std::numeric_limits<double>::max();
    double max = 0.0;
    
    for (double t : times) {
        sum += t;
        if (t < min) min = t;
        if (t > max) max = t;
    }
    
    double average = sum / iterations;
    
    // Calculate standard deviation
    double variance = 0.0;
    for (double t : times) {
        variance += (t - average) * (t - average);
    }
    variance /= iterations;
    double stdDev = std::sqrt(variance);
    
    BenchmarkResult result;
    result.name = name;
    result.durationMs = totalDuration;
    result.averageMs = average;
    result.minMs = min;
    result.maxMs = max;
    result.stdDev = stdDev;
    result.iterations = iterations;
    result.operations = operations;
    result.opsPerSecond = operations > 0 ? (operations / totalDuration) * 1000.0 : 0.0;
    
    return result;
}

} // namespace Benchmark
} // namespace ShaderCandy
