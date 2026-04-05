//
//  LinuxShaderManager.cpp
//  ShaderCandy
//
//  Linux implementation of ShaderManager using GLRenderer
//

#include "../core/ShaderManager.h"
#include "../gl/GLRenderer.h"
#include "../gl/GLShaderCompiler.h"

#include <filesystem>
#include <iostream>

namespace ShaderCandy {

class LinuxShaderManager : public ShaderManager {
public:
  LinuxShaderManager() = default;
  ~LinuxShaderManager() override {
    shaderCompiler_.reset();
    for (auto &program : shaderPrograms_) {
      // glDeleteProgram(program.second); // Requires GL context
    }
    shaderPrograms_.clear();
  }

  bool initialize() override {
    shaderCompiler_ = std::make_unique<Platform::Linux::GLShaderCompiler>();
    if (!shaderCompiler_->initialize()) {
      std::cerr << "LinuxShaderManager: Failed to initialize shader compiler"
                << std::endl;
      return false;
    }

    // Scan default shader directory
    scanShaderDirectory("shaders");
    scanShaderDirectory("shaders/effects");
    scanShaderDirectory("shaders/music");

    return true;
  }

  bool loadShader(const std::string &name,
                  const std::string &path) override {
    unsigned int program = 0;

    // Load vertex shader
    std::string vertexPath = "shaders/base/vertex.glsl";
    std::string fragmentPath = path;

    if (!shaderCompiler_->compileFromFile(fragmentPath, program)) {
      std::cerr << "LinuxShaderManager: Failed to compile shader '" << name
                << "': " << shaderCompiler_->getLastError() << std::endl;
      return false;
    }

    shaderPrograms_[name] = program;
    shaderPaths_[name] = path;
    return true;
  }

  bool reloadShaders() override {
    for (const auto &[name, path] : shaderPaths_) {
      // Delete old program
      auto it = shaderPrograms_.find(name);
      if (it != shaderPrograms_.end()) {
        // glDeleteProgram(it->second); // Would need GL context
      }

      // Reload
      if (!loadShader(name, path)) {
        std::cerr << "LinuxShaderManager: Failed to reload shader '" << name
                  << "'" << std::endl;
        return false;
      }
    }
    return true;
  }

  std::vector<std::string> getAvailableShaders() const override {
    std::vector<std::string> shaders;
    for (const auto &pair : shaderPaths_) {
      shaders.push_back(pair.first);
    }
    return shaders;
  }

  bool setActiveShader(const std::string &name) override {
    if (shaderPrograms_.find(name) != shaderPrograms_.end()) {
      activeShader_ = name;
      return true;
    }
    return false;
  }

  std::string getActiveShader() const override { return activeShader_; }

  void render() override {
    // Rendering handled by GLRenderer - this is for hot-reload callbacks
  }

private:
  void scanShaderDirectory(const std::string &dirPath) {
    try {
      std::filesystem::path dir(dirPath);
      if (!std::filesystem::exists(dir))
        return;

      for (const auto &entry :
           std::filesystem::directory_iterator(dir)) {
        if (entry.is_regular_file()) {
          auto ext = entry.path().extension();
          if (ext == ".frag" || ext == ".glsl") {
            std::string name = entry.path().stem().string();
            if (shaderPaths_.find(name) == shaderPaths_.end()) {
              shaderPaths_[name] = entry.path().string();
            }
          }
        }
      }
    } catch (const std::exception &e) {
      std::cerr << "LinuxShaderManager: Error scanning directory: " << e.what()
                << std::endl;
    }
  }

  std::unique_ptr<Platform::Linux::GLShaderCompiler> shaderCompiler_;
  std::unordered_map<std::string, unsigned int> shaderPrograms_;
};

std::unique_ptr<ShaderManager> createShaderManager() {
  auto manager = std::make_unique<LinuxShaderManager>();
  if (manager->initialize()) {
    return manager;
  }
  return nullptr;
}

} // namespace ShaderCandy