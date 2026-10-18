/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

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
#include <mutex>
#include <sstream>
#include <unordered_map>
#include <vector>

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
        "shaders/audio", "shaders/neural",       "shaders/system",
        "../shaders",    "../shaders/effects",    "../shaders/music",
        "../shaders/audio", "../shaders/neural",  "../shaders/system",
        "../../shaders", "../../shaders/effects", "../../shaders/music",
        "../../shaders/audio", "../../shaders/neural",
        "../../shaders/system"};

    bool foundAny = false;
    for (const auto &dir : searchPaths) {
      if (fs::exists(dir) && fs::is_directory(dir)) {
        foundAny = true;
      }
    }
    if (!foundAny) {
      return false;
    }

    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      for (const auto &dir : searchPaths) {
        if (fs::exists(dir) && fs::is_directory(dir)) {
          scanDirectory(dir);
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
    }

    return true;
  }

  bool loadShader(const std::string &name, const std::string &path) override {
    if (!fs::exists(path)) {
      return false;
    }

    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      shaderPaths_[name] = path;
      try {
        lastWriteTimes_[name] = fs::last_write_time(path);
      } catch (...) {
        // Ignore timestamp read failures
      }

      if (activeShader_.empty()) {
        activeShader_ = name;
      }
    }

    if (shaderChangedCallback_) {
      shaderChangedCallback_(name);
    }

    return true;
  }

  bool reloadShaders() override {
    // Throttle the poll. Without this, every registered shader is stat()ed on
    // every rendered frame (~230 syscalls/frame at 60 fps with the current
    // corpus). A mtime comparison cannot resolve changes finer than this
    // anyway, so polling faster only burns CPU.
    const auto now = std::chrono::steady_clock::now();
    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      if (now - lastReloadPoll_ < reloadPollInterval_) {
        return false;
      }
      lastReloadPoll_ = now;
    }

    std::vector<std::string> reloaded;
    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      for (const auto &[name, path] : shaderPaths_) {
        if (!fs::exists(path)) {
          continue;
        }

        try {
          auto currentWriteTime = fs::last_write_time(path);
          auto it = lastWriteTimes_.find(name);
          if (it == lastWriteTimes_.end() || currentWriteTime > it->second) {
            lastWriteTimes_[name] = currentWriteTime;
            reloaded.push_back(name);
          }
        } catch (...) {
          // Ignore timestamp read failures
        }
      }
    }

    // Callbacks run outside the lock: a handler that queries this manager
    // (or calls back into reloadShaders) would otherwise self-deadlock.
    if (shaderChangedCallback_) {
      for (const auto &name : reloaded) {
        shaderChangedCallback_(name);
      }
    }
    return !reloaded.empty();
  }

  std::vector<std::string> getAvailableShaders() const override {
    std::vector<std::string> result;
    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      result.reserve(shaderPaths_.size());
      for (const auto &pair : shaderPaths_) {
        result.push_back(pair.first);
      }
    }
    std::sort(result.begin(), result.end());
    return result;
  }

  bool setActiveShader(const std::string &name) override {
    std::lock_guard<std::mutex> lock(stateMutex_);
    auto it = shaderPaths_.find(name);
    if (it != shaderPaths_.end()) {
      activeShader_ = name;
      return true;
    }
    return false;
  }

  std::string getActiveShader() const override {
    std::lock_guard<std::mutex> lock(stateMutex_);
    return activeShader_;
  }

  void render() override {
    // Core manager coordinates state; platform renderers handle hardware
    // dispatch
    bool hotReload;
    {
      std::lock_guard<std::mutex> lock(stateMutex_);
      hotReload = hotReloadEnabled_;
    }
    if (hotReload) {
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

  // Guards shaderPaths_, lastWriteTimes_, activeShader_, hotReloadEnabled_ and
  // the reload-poll state. reloadShaders() can be driven from more than one
  // thread, and the maps are rehashable.
  mutable std::mutex stateMutex_;

  std::unordered_map<std::string, fs::file_time_type> lastWriteTimes_;
  std::chrono::steady_clock::time_point lastReloadPoll_{};
  std::chrono::milliseconds reloadPollInterval_{500};
};

std::unique_ptr<ShaderManager> createShaderManager() {
  return std::make_unique<UnifiedShaderManager>();
}

} // namespace ShaderCandy
