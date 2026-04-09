#include "BenchmarkFramework.h"
#include "../src/core/ShaderManager.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <map>
#include <filesystem>

namespace ShaderCandy {
namespace Regression {

struct ShaderTestResult {
    std::string shaderName;
    bool compiledSuccessfully;
    double compilationTimeMs;
    std::string errorMessage;
    size_t uniformCount;
    size_t textureCount;
};

struct BaselineData {
    std::map<std::string, ShaderTestResult> results;
    std::string timestamp;
    std::string gitCommit;
};

class ShaderRegressionDetector {
public:
    ShaderRegressionDetector(const std::string& baselinePath) 
        : baselinePath_(baselinePath) {
        loadBaseline();
    }
    
    // Run shader compilation tests and compare against baseline
    std::vector<ShaderTestResult> runRegressionTests() {
        std::vector<ShaderTestResult> currentResults;
        
        // Get list of all shaders
        std::vector<std::string> shaderNames = getAllShaderNames();
        
        for (const auto& name : shaderNames) {
            ShaderTestResult result;
            result.shaderName = name;
            
            // Measure compilation time
            auto start = std::chrono::high_resolution_clock::now();
            
            // Attempt compilation (platform-specific)
            #ifdef __APPLE__
            result.compiledSuccessfully = compileMetalShader(name);
            #elif __linux__
            result.compiledSuccessfully = compileGLSLShader(name);
            #endif
            
            auto end = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> duration = end - start;
            result.compilationTimeMs = duration.count();
            
            currentResults.push_back(result);
        }
        
        return currentResults;
    }
    
    // Compare current results against baseline
    struct RegressionReport {
        struct ShaderRegression {
            std::string shaderName;
            double timeChangePercent;
            bool statusChanged;
            bool wasRegression;
        };
        
        std::vector<ShaderRegression> regressions;
        size_t totalShaders;
        size_t changedStatusCount;
        size_t performanceRegressions;
    };
    
    RegressionReport compareAgainstBaseline(
        const std::vector<ShaderTestResult>& currentResults) {
        
        RegressionReport report;
        report.totalShaders = currentResults.size();
        report.changedStatusCount = 0;
        report.performanceRegressions = 0;
        
        for (const auto& current : currentResults) {
            auto it = baseline_.results.find(current.shaderName);
            if (it != baseline_.results.end()) {
                const auto& baseline = it->second;
                
                RegressionReport::ShaderRegression reg;
                reg.shaderName = current.shaderName;
                reg.statusChanged = (current.compiledSuccessfully != baseline.compiledSuccessfully);
                
                if (baseline.compilationTimeMs > 0) {
                    double change = ((current.compilationTimeMs - baseline.compilationTimeMs) / 
                                   baseline.compilationTimeMs) * 100.0;
                    reg.timeChangePercent = change;
                    reg.wasRegression = (change > 20.0); // 20% threshold
                } else {
                    reg.timeChangePercent = 0.0;
                    reg.wasRegression = false;
                }
                
                report.regressions.push_back(reg);
                
                if (reg.statusChanged) {
                    report.changedStatusCount++;
                }
                if (reg.wasRegression) {
                    report.performanceRegressions++;
                }
            }
        }
        
        return report;
    }
    
    // Save current results as new baseline
    void saveBaseline(const std::vector<ShaderTestResult>& results) {
        baseline_.results.clear();
        
        for (const auto& result : results) {
            baseline_.results[result.shaderName] = result;
        }
        
        baseline_.timestamp = getCurrentTimestamp();
        baseline_.gitCommit = getGitCommit();
        
        saveBaselineToFile();
    }
    
    void printReport(const RegressionReport& report) {
        std::cout << "\n=== Shader Regression Report ===\n";
        std::cout << "Total Shaders Tested: " << report.totalShaders << "\n";
        std::cout << "Status Changes: " << report.changedStatusCount << "\n";
        std::cout << "Performance Regressions: " << report.performanceRegressions << "\n";
        
        if (!report.regressions.empty()) {
            std::cout << "\nShader Details:\n";
            std::cout << "----------------------------------------\n";
            for (const auto& reg : report.regressions) {
                if (reg.statusChanged || reg.wasRegression) {
                    std::cout << reg.shaderName << ":\n";
                    if (reg.statusChanged) {
                        std::cout << "  ⚠️  Status changed (compilation result differs)\n";
                    }
                    if (reg.wasRegression) {
                        std::cout << "  📈 Performance regression: " 
                                  << reg.timeChangePercent << "% slower\n";
                    } else if (reg.timeChangePercent < -20.0) {
                        std::cout << "  📉 Performance improvement: " 
                                  << reg.timeChangePercent << "% faster\n";
                    }
                }
            }
        }
        
        if (report.changedStatusCount == 0 && report.performanceRegressions == 0) {
            std::cout << "\n✅ No regressions detected!\n";
        }
    }
    
private:
    std::string baselinePath_;
    BaselineData baseline_;
    
    void loadBaseline() {
        // Load baseline from file if it exists
        std::ifstream file(baselinePath_);
        if (file.is_open()) {
            // Parse baseline file (JSON or custom format)
            // For now, just initialize empty baseline
            file.close();
        }
    }
    
    void saveBaselineToFile() {
        std::ofstream file(baselinePath_);
        if (file.is_open()) {
            // Save in custom format for now
            file << "# ShaderCandy Regression Baseline\n";
            file << "# Timestamp: " << baseline_.timestamp << "\n";
            file << "# Git Commit: " << baseline_.gitCommit << "\n\n";
            
            for (const auto& [name, result] : baseline_.results) {
                file << name << ","
                     << (result.compiledSuccessfully ? "1" : "0") << ","
                     << result.compilationTimeMs << "\n";
            }
            
            file.close();
        }
    }
    
    std::vector<std::string> getAllShaderNames() {
        std::vector<std::string> names;
        
        // Scan shaders/effects directory
        std::filesystem::path shadersDir("shaders/effects");
        if (std::filesystem::exists(shadersDir)) {
            for (const auto& entry : std::filesystem::directory_iterator(shadersDir)) {
                if (entry.path().extension() == ".metal" || 
                    entry.path().extension() == ".frag") {
                    names.push_back(entry.path().stem().string());
                }
            }
        }
        
        return names;
    }
    
    #ifdef __APPLE__
    bool compileMetalShader(const std::string& name) {
        // Use xcrun to compile Metal shader
        std::string command = "xcrun -sdk macosx metal -c shaders/effects/" + name + 
                             ".metal -o /dev/null 2>&1";
        int result = system(command.c_str());
        return (result == 0);
    }
    #endif
    
    #ifdef __linux__
    bool compileGLSLShader(const std::string& name) {
        // Use glslangValidator to compile GLSL shader
        std::string command = "glslangValidator -S frag shaders/effects/" + name + 
                             ".frag > /dev/null 2>&1";
        int result = system(command.c_str());
        return (result == 0);
    }
    #endif
    
    std::string getCurrentTimestamp() {
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        std::stringstream ss;
        ss << std::ctime(&time_t);
        return ss.str();
    }
    
    std::string getGitCommit() {
        FILE* pipe = popen("git rev-parse HEAD", "r");
        if (!pipe) return "unknown";
        
        char buffer[128];
        std::string result = "";
        while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
            result += buffer;
        }
        pclose(pipe);
        
        if (!result.empty() && result.back() == '\n') {
            result.pop_back();
        }
        
        return result;
    }
};

} // namespace Regression
} // namespace ShaderCandy

// Main function for standalone regression detection
int main(int argc, char* argv[]) {
    std::string baselinePath = "shader_regression_baseline.txt";
    bool saveBaseline = false;
    bool runTests = true;
    
    // Parse arguments
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--save-baseline") {
            saveBaseline = true;
        } else if (arg == "--baseline-path") {
            if (i + 1 < argc) {
                baselinePath = argv[++i];
            }
        } else if (arg == "--help") {
            std::cout << "Usage: " << argv[0] << " [OPTIONS]\n";
            std::cout << "Options:\n";
            std::cout << "  --save-baseline    Save current results as new baseline\n";
            std::cout << "  --baseline-path    Path to baseline file\n";
            std::cout << "  --help             Show this help\n";
            return 0;
        }
    }
    
    ShaderCandy::Regression::ShaderRegressionDetector detector(baselinePath);
    
    if (runTests) {
        auto results = detector.runRegressionTests();
        
        if (saveBaseline) {
            detector.saveBaseline(results);
            std::cout << "Baseline saved to " << baselinePath << "\n";
        } else {
            auto report = detector.compareAgainstBaseline(results);
            detector.printReport(report);
        }
    }
    
    return 0;
}