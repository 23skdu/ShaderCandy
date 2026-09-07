//
//  ShaderCandy
//  Unified Core ShaderManager Implementation
//

#include "ShaderManager.h"
#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <unordered_map>

namespace fs = std::filesystem;

namespace ShaderCandy {

class UnifiedShaderManager : public ShaderManager {
public:
  UnifiedShaderManager() = default;
  ~UnifiedShaderManager() override = default;

  bool initialize() override {
    // Scan common shader locations
    const std::vector<std::string> searchPaths = {
        "shaders",       "shaders/effects",       "shaders/music",
        "../shaders",    "../shaders/effects",    "../shaders/music",
        "../../shaders", "../../shaders/effects", "../../shaders/music"};

    bool foundAny = false;
    for (const auto &dir : searchPaths) {
      if (fs::exists(dir) && fs::is_directory(dir)) {
        scanDirectory(dir);
        foundAny = true;
      }
    }

    if (!shaderPaths_.empty()) {
      auto it = shaderPaths_.find("default");
      if (it != shaderPaths_.end()) {
        activeShader_ = "default";
      } else {
        activeShader_ = shaderPaths_.begin()->first;
      }
    }

    return foundAny;
  }

  bool loadShader(const std::string &name, const std::string &path) override {
    if (!fs::exists(path)) {
      return false;
    }

    shaderPaths_[name] = path;
    try {
      lastWriteTimes_[name] = fs::last_write_time(path);
    } catch (...) {
      // Ignore timestamp read failures
    }

    if (activeShader_.empty()) {
      activeShader_ = name;
    }

    if (shaderChangedCallback_) {
      shaderChangedCallback_(name);
    }

    return true;
  }

  bool reloadShaders() override {
    bool reloadedAny = false;
    for (const auto &[name, path] : shaderPaths_) {
      if (!fs::exists(path)) {
        continue;
      }

      try {
        auto currentWriteTime = fs::last_write_time(path);
        auto it = lastWriteTimes_.find(name);
        if (it == lastWriteTimes_.end() || currentWriteTime > it->second) {
          lastWriteTimes_[name] = currentWriteTime;
          reloadedAny = true;
          if (shaderChangedCallback_) {
            shaderChangedCallback_(name);
          }
        }
      } catch (...) {
        // Ignore timestamp read failures
      }
    }
    return reloadedAny;
  }

  std::vector<std::string> getAvailableShaders() const override {
    std::vector<std::string> result;
    result.reserve(shaderPaths_.size());
    for (const auto &pair : shaderPaths_) {
      result.push_back(pair.first);
    }
    std::sort(result.begin(), result.end());
    return result;
  }

  bool setActiveShader(const std::string &name) override {
    auto it = shaderPaths_.find(name);
    if (it != shaderPaths_.end()) {
      activeShader_ = name;
      return true;
    }
    return false;
  }

  std::string getActiveShader() const override { return activeShader_; }

  void render() override {
    // Core manager coordinates state; platform renderers handle hardware
    // dispatch
    if (hotReloadEnabled_) {
      reloadShaders();
    }
  }

private:
  void scanDirectory(const std::string &dirPath) {
    std::error_code ec;
    for (const auto &entry : fs::directory_iterator(dirPath, ec)) {
      if (entry.is_regular_file()) {
        std::string ext = entry.path().extension().string();
        if (ext == ".metal" || ext == ".frag" || ext == ".glsl") {
          std::string stem = entry.path().stem().string();
          // Exclude base utilities and helpers
          if (stem == "common" || stem == "utils" || stem == "ShaderInterop" ||
              stem == "vertex" || stem == "debug_overlay") {
            continue;
          }
          // Avoid overwriting if already discovered in higher-priority path
          auto [it, inserted] =
              shaderPaths_.try_emplace(stem, entry.path().string());
          if (inserted) {
            try {
              lastWriteTimes_[stem] = fs::last_write_time(entry.path());
            } catch (...) {
            }
          }
        }
      }
    }
  }

  std::unordered_map<std::string, fs::file_time_type> lastWriteTimes_;
};

std::unique_ptr<ShaderManager> createShaderManager() {
  return std::make_unique<UnifiedShaderManager>();
}

} // namespace ShaderCandy
