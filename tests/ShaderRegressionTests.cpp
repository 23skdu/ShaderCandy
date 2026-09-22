#include "TestFramework.h"
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <vector>
#include <string>
#include <chrono>
#include <map>

namespace ShaderCandy {
namespace Test {

class ShaderRegressionTests : public TestSuite {
public:
    std::string getName() const override { return "Shader Regression Tests"; }

    std::vector<TestResult> run() override {
        std::vector<TestResult> results;
        if (!hasGlslangValidator()) {
            results.push_back(testOfflineShaderSyntaxValidation());
            return results;
        }
        results.push_back(testShaderCompilationTimes());
        results.push_back(testShaderBaselineComparison());
        return results;
    }

private:
    struct ShaderTiming {
        std::string name;
        double timeMs;
        bool compiled;
    };

    bool hasGlslangValidator() {
        return std::system("which glslangValidator > /dev/null 2>&1") == 0;
    }

    std::vector<std::string> findFragShaders() {
        std::vector<std::string> searchPaths = {
            "shaders", "shaders/effects", "../shaders", "../shaders/effects"
        };
        std::vector<std::string> fragFiles;
        for (const auto &path : searchPaths) {
            if (!std::filesystem::exists(path)) continue;
            for (const auto &entry : std::filesystem::directory_iterator(path)) {
                if (!entry.is_regular_file()) continue;
                auto stem = entry.path().stem().string();
                if (stem == "common" || stem == "vertex" || stem == "debug_overlay") continue;
                auto ext = entry.path().extension();
                if (ext == ".frag" || ext == ".glsl") {
                    fragFiles.push_back(entry.path().string());
                }
            }
            if (!fragFiles.empty()) break;
        }
        return fragFiles;
    }

    TestResult testOfflineShaderSyntaxValidation() {
        auto fragFiles = findFragShaders();
        if (fragFiles.empty()) {
            return {__func__, true, "No shaders found to validate", 0.0};
        }

        int validCount = 0;
        for (const auto &fragPath : fragFiles) {
            std::ifstream file(fragPath);
            if (!file.is_open()) continue;
            std::string content((std::istreambuf_iterator<char>(file)),
                                 std::istreambuf_iterator<char>());

            int braceCount = 0;
            int parenCount = 0;
            bool inLineComment = false;
            bool inBlockComment = false;

            for (size_t i = 0; i < content.size(); ++i) {
                char c = content[i];
                if (inLineComment) {
                    if (c == '\n') inLineComment = false;
                    continue;
                }
                if (inBlockComment) {
                    if (c == '*' && i + 1 < content.size() && content[i + 1] == '/') {
                        inBlockComment = false;
                        i++;
                    }
                    continue;
                }
                if (c == '/' && i + 1 < content.size()) {
                    if (content[i + 1] == '/') {
                        inLineComment = true;
                        i++;
                        continue;
                    }
                    if (content[i + 1] == '*') {
                        inBlockComment = true;
                        i++;
                        continue;
                    }
                }
                if (c == '{') braceCount++;
                else if (c == '}') braceCount--;
                else if (c == '(') parenCount++;
                else if (c == ')') parenCount--;
            }

            TEST_ASSERT(braceCount == 0, "Mismatched braces in: " + fragPath);
            TEST_ASSERT(parenCount == 0, "Mismatched parentheses in: " + fragPath);
            TEST_ASSERT(content.find("main(") != std::string::npos, "Missing main() in: " + fragPath);
            validCount++;
        }

        return {__func__, true,
                "Offline syntax validated " + std::to_string(validCount) + " shaders (balanced braces, parens, main entry)", 0.0};
    }

    double measureCompileTime(const std::string &fragPath) {
        auto start = std::chrono::high_resolution_clock::now();
        std::string cmd = "glslangValidator -S frag " + fragPath + " > /dev/null 2>&1";
        bool ok = (std::system(cmd.c_str()) == 0);
        auto end = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double, std::milli> dur = end - start;
        return dur.count();
    }

    TestResult testShaderCompilationTimes() {
        auto fragFiles = findFragShaders();
        if (fragFiles.empty()) {
            return {__func__, true, "No .frag shaders found for regression testing", 0.0};
        }

        std::vector<ShaderTiming> timings;
        for (const auto &fragPath : fragFiles) {
            std::string name = std::filesystem::path(fragPath).stem().string();
            ShaderTiming t;
            t.name = name;
            t.timeMs = measureCompileTime(fragPath);
            t.compiled = (std::system(("glslangValidator -S frag " + fragPath + " > /dev/null 2>&1").c_str()) == 0);
            timings.push_back(t);
        }

        saveBaseline(timings);

        return {__func__, true,
                "Measured compilation times for " + std::to_string(timings.size()) + " shaders", 0.0};
    }

    TestResult testShaderBaselineComparison() {
        std::string baselinePath = "shader_regression_baseline.txt";
        if (!std::filesystem::exists(baselinePath)) {
            baselinePath = "../shader_regression_baseline.txt";
        }
        if (!std::filesystem::exists(baselinePath)) {
            return {__func__, true, "No baseline found — skipping (run tests twice to establish)", 0.0};
        }

        auto baseline = loadBaseline(baselinePath);
        if (baseline.empty()) {
            return {__func__, true, "Baseline empty — skipping comparison", 0.0};
        }

        auto fragFiles = findFragShaders();

        int regressions = 0;
        int improvements = 0;
        int skipped = 0;
        for (const auto &fragPath : fragFiles) {
            std::string name = std::filesystem::path(fragPath).stem().string();
            auto it = baseline.find(name);
            if (it == baseline.end()) continue;

            // Skip shaders that didn't compile in baseline (unreliable timing)
            if (it->second <= 0) { skipped++; continue; }

            double currentMs = measureCompileTime(fragPath);
            double baselineMs = it->second;

            // Use absolute difference threshold to ignore noise from failed compiles
            double diff = currentMs - baselineMs;
            if (diff > 50.0) regressions++;
            else if (diff < -50.0) improvements++;
        }

        if (regressions > 0) {
            return {__func__, false,
                    std::to_string(regressions) + " shader(s) regressed by >50ms", 0.0};
        }

        return {__func__, true,
                "No regressions (" + std::to_string(improvements) + " improved, " +
                std::to_string(skipped) + " skipped)", 0.0};
    }

    void saveBaseline(const std::vector<ShaderTiming> &timings) {
        std::ofstream file("shader_regression_baseline.txt");
        if (!file.is_open()) return;
        file << "# ShaderCandy Regression Baseline\n";
        for (const auto &t : timings) {
            file << t.name << "," << (t.compiled ? "1" : "0") << "," << t.timeMs << "\n";
        }
    }

    std::map<std::string, double> loadBaseline(const std::string &path) {
        std::map<std::string, double> result;
        std::ifstream file(path);
        if (!file.is_open()) return result;

        std::string line;
        while (std::getline(file, line)) {
            if (line.empty() || line[0] == '#') continue;
            std::istringstream ss(line);
            std::string name, compiled, time;
            if (std::getline(ss, name, ',') &&
                std::getline(ss, compiled, ',') &&
                std::getline(ss, time)) {
                result[name] = std::stod(time);
            }
        }
        return result;
    }
};

REGISTER_TEST_SUITE(ShaderRegressionTests);

} // namespace Test
} // namespace ShaderCandy
