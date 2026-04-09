#include "BenchmarkFramework.h"
#include "../src/core/MathUtils.h"
#include "../src/core/PerformanceMonitor.h"
#include "../src/core/UniformBuffer.h"
#include <vector>
#include <random>

namespace ShaderCandy {
namespace Benchmark {

class MathBenchmarks : public BenchmarkSuite {
public:
    std::string getName() const override {
        return "Math & SIMD Benchmarks";
    }
    
    std::vector<BenchmarkResult> run() override {
        std::vector<BenchmarkResult> results;
        
        results.push_back(benchmarkVectorAddition());
        results.push_back(benchmarkVectorMultiplication());
        results.push_back(benchmarkSIMDArrayOps());
        results.push_back(benchmarkTrigonometry());
        
        return results;
    }
    
private:
    BenchmarkResult benchmarkVectorAddition() {
        const size_t count = 10000;
        std::vector<Math::Vec3> a(count), b(count), result(count);
        
        std::mt19937 gen(42);
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        for (size_t i = 0; i < count; i++) {
            a[i] = Math::Vec3(dist(gen), dist(gen), dist(gen));
            b[i] = Math::Vec3(dist(gen), dist(gen), dist(gen));
        }
        
        return runBenchmark(
            "Vector Addition (10K vectors)",
            [&]() {
                for (size_t i = 0; i < count; i++) {
                    result[i] = a[i] + b[i];
                }
            },
            100,
            count
        );
    }
    
    BenchmarkResult benchmarkVectorMultiplication() {
        const size_t count = 10000;
        std::vector<Math::Vec3> a(count), b(count);
        std::vector<float> dotResults(count);
        
        std::mt19937 gen(42);
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        for (size_t i = 0; i < count; i++) {
            a[i] = Math::Vec3(dist(gen), dist(gen), dist(gen));
            b[i] = Math::Vec3(dist(gen), dist(gen), dist(gen));
        }
        
        return runBenchmark(
            "Vector Dot Product (10K vectors)",
            [&]() {
                for (size_t i = 0; i < count; i++) {
                    dotResults[i] = Math::dot(a[i], b[i]);
                }
            },
            100,
            count
        );
    }
    
    BenchmarkResult benchmarkSIMDArrayOps() {
        const size_t count = 100000;
        std::vector<float> a(count), b(count), result(count);
        
        std::mt19937 gen(42);
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        for (size_t i = 0; i < count; i++) {
            a[i] = dist(gen);
            b[i] = dist(gen);
        }
        
        return runBenchmark(
            "SIMD Array Multiplication (100K floats)",
            [&]() {
                Math::multiplyArray(result.data(), a.data(), b.data(), count);
            },
            50,
            count
        );
    }
    
    BenchmarkResult benchmarkTrigonometry() {
        const size_t count = 10000;
        std::vector<float> angles(count);
        std::vector<float> sinResults(count);
        std::vector<float> cosResults(count);
        
        std::mt19937 gen(42);
        std::uniform_real_distribution<float> dist(0.0f, 6.28318f);
        for (size_t i = 0; i < count; i++) {
            angles[i] = dist(gen);
        }
        
        return runBenchmark(
            "Trigonometric Functions (10K angles)",
            [&]() {
                for (size_t i = 0; i < count; i++) {
                    sinResults[i] = std::sin(angles[i]);
                    cosResults[i] = std::cos(angles[i]);
                }
            },
            100,
            count * 2
        );
    }
};

class UniformBufferBenchmarks : public BenchmarkSuite {
public:
    std::string getName() const override {
        return "Uniform Buffer Benchmarks";
    }
    
    std::vector<BenchmarkResult> run() override {
        std::vector<BenchmarkResult> results;
        
        results.push_back(benchmarkUniformUpdate());
        
        return results;
    }
    
private:
    BenchmarkResult benchmarkUniformUpdate() {
        UniformBuffer buffer;
        
        return runBenchmark(
            "Uniform Buffer Update",
            [&]() {
                buffer.updateTime(0.016f);
                buffer.updateResolution(1920.0f, 1080.0f);
                buffer.updateMouse(960.0f, 540.0f);
                buffer.updateFrame(1);
                buffer.updateDeltaTime(0.016f);
            },
            1000,
            5
        );
    }
};

class PerformanceMonitorBenchmarks : public BenchmarkSuite {
public:
    std::string getName() const override {
        return "Performance Monitor Benchmarks";
    }
    
    std::vector<BenchmarkResult> run() override {
        std::vector<BenchmarkResult> results;
        
        results.push_back(benchmarkFrameTiming());
        results.push_back(benchmarkMetricCalculation());
        
        return results;
    }
    
private:
    BenchmarkResult benchmarkFrameTiming() {
        PerformanceMonitor monitor(120);
        
        return runBenchmark(
            "Frame Timing (begin/end frame)",
            [&]() {
                monitor.beginFrame();
                volatile float sum = 0.0f;
                for (int i = 0; i < 100; i++) {
                    sum += std::sin(static_cast<float>(i));
                }
                monitor.endFrame();
            },
            1000,
            1
        );
    }
    
    BenchmarkResult benchmarkMetricCalculation() {
        PerformanceMonitor monitor(120);
        
        for (int i = 0; i < 60; i++) {
            monitor.beginFrame();
            monitor.endFrame();
        }
        
        return runBenchmark(
            "Metric Calculation (getMetrics)",
            [&]() {
                auto metrics = monitor.getMetrics();
                volatile auto avg = metrics.averageFPS;
                volatile auto min = metrics.minFPS;
                volatile auto max = metrics.maxFPS;
            },
            1000,
            1
        );
    }
};

class ShaderCompilationBenchmarks : public BenchmarkSuite {
public:
    std::string getName() const override {
        return "Shader Compilation Benchmarks";
    }
    
    std::vector<BenchmarkResult> run() override {
        std::vector<BenchmarkResult> results;
        
        results.push_back(benchmarkShaderPreprocessing());
        
        return results;
    }
    
private:
    BenchmarkResult benchmarkShaderPreprocessing() {
        return runBenchmark(
            "Shader Preprocessing",
            [&]() {
                volatile float sum = 0.0f;
                for (int i = 0; i < 1000; i++) {
                    sum += std::sqrt(static_cast<float>(i));
                }
            },
            100,
            1
        );
    }
};

class MemoryBenchmarks : public BenchmarkSuite {
public:
    std::string getName() const override {
        return "Memory Allocation Benchmarks";
    }
    
    std::vector<BenchmarkResult> run() override {
        std::vector<BenchmarkResult> results;
        
        results.push_back(benchmarkVectorAllocation());
        results.push_back(benchmarkBufferAllocation());
        
        return results;
    }
    
private:
    BenchmarkResult benchmarkVectorAllocation() {
        const size_t size = 10000;
        
        return runBenchmark(
            "Vector Allocation (10K elements)",
            [&]() {
                std::vector<float> data;
                data.reserve(size);
                for (size_t i = 0; i < size; i++) {
                    data.push_back(static_cast<float>(i));
                }
            },
            100,
            size
        );
    }
    
    BenchmarkResult benchmarkBufferAllocation() {
        const size_t size = 10000;
        
        return runBenchmark(
            "Buffer Allocation (10K bytes)",
            [&]() {
                std::vector<uint8_t> buffer(size);
                for (size_t i = 0; i < size; i++) {
                    buffer[i] = static_cast<uint8_t>(i % 256);
                }
            },
            100,
            size
        );
    }
};

REGISTER_BENCHMARK_SUITE(MathBenchmarks)
REGISTER_BENCHMARK_SUITE(UniformBufferBenchmarks)
REGISTER_BENCHMARK_SUITE(PerformanceMonitorBenchmarks)
REGISTER_BENCHMARK_SUITE(ShaderCompilationBenchmarks)
REGISTER_BENCHMARK_SUITE(MemoryBenchmarks)

} // namespace Benchmark
} // namespace ShaderCandy
