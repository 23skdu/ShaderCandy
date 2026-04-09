#include "BenchmarkFramework.h"
#include <iostream>
#include <string>
#include <vector>

using namespace ShaderCandy::Benchmark;

void printUsage(const char* programName) {
    std::cout << "Usage: " << programName << " [OPTIONS]\n"
              << "Options:\n"
              << "  --list               List all available benchmarks\n"
              << "  --run <name>         Run specific benchmark suite\n"
              << "  --all                Run all benchmarks (default)\n"
              << "  --verbose            Show detailed results\n"
              << "  --throughput         Show throughput metrics\n"
              << "  --help               Show this help message\n";
}

int main(int argc, char* argv[]) {
    bool listOnly = false;
    bool runAll = true;
    bool verbose = false;
    bool showThroughput = false;
    std::string runName = "";
    
    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--list") {
            listOnly = true;
        } else if (arg == "--run") {
            if (i + 1 < argc) {
                runName = argv[++i];
                runAll = false;
            } else {
                std::cerr << "Error: --run requires a benchmark name\n";
                printUsage(argv[0]);
                return 1;
            }
        } else if (arg == "--all") {
            runAll = true;
        } else if (arg == "--verbose") {
            verbose = true;
        } else if (arg == "--throughput") {
            showThroughput = true;
        } else if (arg == "--help" || arg == "-h") {
            printUsage(argv[0]);
            return 0;
        } else {
            std::cerr << "Unknown option: " << arg << "\n";
            printUsage(argv[0]);
            return 1;
        }
    }
    
    auto& framework = BenchmarkFramework::getInstance();
    
    if (listOnly) {
        std::cout << "Available benchmark suites:\n";
        return 0;
    }
    
    std::cout << "ShaderCandy Performance Benchmarks\n";
    std::cout << "==================================\n\n";
    
    if (runAll) {
        framework.runAll();
    } else {
        framework.runSuite(runName);
    }
    
    framework.printResults();
    
    if (showThroughput) {
        framework.printThroughputResults();
    }
    
    auto summary = framework.getSummary();
    std::cout << "\nSummary:\n";
    std::cout << "  Total Benchmarks: " << summary.totalBenchmarks << "\n";
    std::cout << "  Total Duration: " << summary.totalDurationMs << " ms\n";
    std::cout << "  Fastest Benchmark: " << summary.fastestBenchmark << " ms avg\n";
    std::cout << "  Slowest Benchmark: " << summary.slowestBenchmark << " ms avg\n";
    
    return 0;
}