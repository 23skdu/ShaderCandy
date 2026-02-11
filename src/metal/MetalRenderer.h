#pragma once

#include "../core/ShaderManager.h"
#include <memory>

// Metal headers removed from public C++ interface

namespace ShaderCandy {

// Forward declarations for macOS types

// Metal-specific shader manager for macOS
class MetalRenderer : public ShaderManager {
public:
  MetalRenderer();
  ~MetalRenderer() override;

  // Disable copy
  MetalRenderer(const MetalRenderer &) = delete;
  MetalRenderer &operator=(const MetalRenderer &) = delete;

  // Enable move
  MetalRenderer(MetalRenderer &&) noexcept;
  MetalRenderer &operator=(MetalRenderer &&) noexcept;

  // ShaderManager interface
  bool initialize() override;
  bool loadShader(const std::string &name, const std::string &path) override;
  bool reloadShaders() override;
  std::vector<std::string> getAvailableShaders() const override;
  bool setActiveShader(const std::string &name) override;
  std::string getActiveShader() const override;
  void render() override;

  // Metal-specific methods
  bool initializeWithDevice(void *device); // Takes id<MTLDevice>
  void setViewport(int width, int height);
  void updateUniforms(float time, int frame);

  // Shader compilation
  bool compileFromSource(const std::string &source,
                         const std::string &entryPoint);
  bool compileFromFile(const std::string &path);
  bool compileFromLibrary(const std::string &metallibPath);

  // Pipeline management
  void createPipelineState(const std::string &vertexFunc,
                           const std::string &fragmentFunc);

  // Hot reload support
  void checkForShaderChanges();
  void setShaderDirectory(const std::string &path);

  // Performance
  float getLastFrameTimeMs() const;
  int getFPS() const;

private:
  class Impl;
  std::unique_ptr<Impl> pImpl;

  // Platform-agnostic state
  std::string shaderDirectory_;
  int viewportWidth_ = 1920;
  int viewportHeight_ = 1080;
  float lastFrameTimeMs_ = 0.0f;
  int currentFPS_ = 0;
};

// Factory function declaration
std::unique_ptr<ShaderManager> createMetalRenderer();

} // namespace ShaderCandy
