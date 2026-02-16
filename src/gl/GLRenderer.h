//
//  GLRenderer.h
//  ShaderCandy
//
//  Linux OpenGL Renderer - Matches MetalRenderer interface
//

#pragma once

#include <functional>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "../core/ShaderInterop.h"

namespace ShaderCandy {
namespace Platform {
namespace Linux {

enum class GLRendererErrorCode {
  None = 0,
  ContextCreationFailed,
  ShaderCompilationFailed,
  ProgramLinkFailed,
  TextureCreationFailed,
  DeviceLost,
  ResourceExhausted,
  InvalidState
};

struct GLRendererError {
  GLRendererErrorCode code;
  std::string message;
  std::string shaderName;
  std::string compilerError;
  int lineNumber;
};

struct GLPerformanceMetrics {
  double currentFPS = 0.0;
  double averageFPS = 0.0;
  double minFPS = 0.0;
  double maxFPS = 0.0;
  double frameTimeMs = 0.0;
  double gpuTimeMs = 0.0;
  double cpuTimeMs = 0.0;
  unsigned int droppedFrames = 0;
  size_t memoryUsageBytes = 0;
};

enum class GLToneMapping { None = 0, ACES, Reinhard, Filmic, Hable };

enum class GLBloomQuality { Low = 0, Medium, High, Ultra };

struct GLBloomConfig {
  bool enabled = true;
  GLBloomQuality quality = GLBloomQuality::Medium;
  float intensity = 1.0f;
  float threshold = 0.8f;
  int blurRadius = 5;
};

struct GLParticleConfig {
  int count = 1000;
  bool enabled = false;
  float gravity = 9.81f;
  float speed = 1.0f;
};

class GLRenderer {
public:
  GLRenderer();
  ~GLRenderer();

  // Initialization
  bool initialize(void *display, void *window, bool isGLES = false);
  void shutdown();

  bool isInitialized() const { return initialized_; }
  std::string getGLVersion() const;
  std::string getGLSLVersion() const;

  // Shader Management
  bool loadShader(const std::string &name, const std::string &path);
  bool reloadCurrentShader();
  std::vector<std::string> availableShaderNames() const;
  bool setActiveShader(const std::string &name);
  std::string activeShaderName() const { return currentShader_; }

  // Rendering
  void render(float time);
  void resize(int width, int height);

  // Uniforms
  void setSpeed(float speed) { uniforms_.speed = speed; }
  void setIntensity(float intensity) { uniforms_.intensity = intensity; }
  void setMouse(float x, float y, int buttons);
  void setAudioData(float volume, float bass, float mid, float treble,
                    float beat);
  void setGravity(float gravity) { uniforms_.gravity = gravity; }

  // Audio Reactivity
  void setAudioReactivityEnabled(bool enabled) {
    audioReactivityEnabled_ = enabled;
  }
  bool isAudioReactivityEnabled() const { return audioReactivityEnabled_; }

  // Bloom
  void setBloomEnabled(bool enabled);
  void setBloomQuality(GLBloomQuality quality);
  void setBloomIntensity(float intensity);
  void setBloomThreshold(float threshold);

  // Particles
  void setParticlesEnabled(bool enabled);
  void setParticleCount(int count);
  void setParticleGravity(float gravity);

  // HDR / Tone Mapping
  void setHDREnabled(bool enabled) { hdrEnabled_ = enabled; }
  bool isHDREnabled() const { return hdrEnabled_; }
  void setToneMapping(GLToneMapping toneMapping);
  GLToneMapping getToneMapping() const { return toneMapping_; }

  // Performance
  GLPerformanceMetrics getMetrics();
  void resetMetrics();

  // Hot reload
  void setHotReloadEnabled(bool enabled) { hotReloadEnabled_ = enabled; }
  bool isHotReloadEnabled() const { return hotReloadEnabled_; }
  void checkForShaderReload();

  // Error handling
  GLRendererError getLastError() const { return lastError_; }
  void clearError() { lastError_ = {GLRendererErrorCode::None, "", "", "", 0}; }

private:
  bool initialized_ = false;
  bool isGLES_ = false;

  void *display_ = nullptr;
  void *window_ = nullptr;
  unsigned int vao_ = 0;
  unsigned int vbo_ = 0;
  unsigned int ebo_ = 0;
  std::string glVersion_;
  std::string glslVersion_;

  // Shader programs
  unsigned int currentProgram_ = 0;
  std::string currentShader_;
  std::unordered_map<std::string, unsigned int> shaderPrograms_;

  // Framebuffer for post-processing
  unsigned int fbo_ = 0;
  unsigned int fboTexture_ = 0;
  unsigned int rbo_ = 0;

  // Bloom
  unsigned int bloomFBO_[2] = {0, 0};
  unsigned int bloomTexture_[2] = {0, 0};
  unsigned int bloomProgram_ = 0;
  GLBloomConfig bloomConfig_;

  // Quad VAO/VBO
  void setupQuad();

  // Shader compilation
  unsigned int compileShader(const std::string &source, unsigned int type);
  unsigned int linkProgram(unsigned int vs, unsigned int fs);
  std::string loadShaderSource(const std::string &path);

  // Uniforms
  Uniforms uniforms_;
  int uniformsLocation_ = -1;

  // Audio
  bool audioReactivityEnabled_ = false;

  // HDR
  bool hdrEnabled_ = false;
  GLToneMapping toneMapping_ = GLToneMapping::ACES;

  // Performance tracking
  GLPerformanceMetrics metrics_;
  double lastFrameTime_ = 0.0;
  double fpsAccumulator_ = 0.0;
  int frameCount_ = 0;

  // Hot reload
  bool hotReloadEnabled_ = true;
  std::unordered_map<std::string, double> shaderModTimes_;

  // Error state
  GLRendererError lastError_;

  // Callbacks
  std::function<void(const std::string &)> shaderChangedCallback_;

  // Helper to set error
  void setError(GLRendererErrorCode code, const std::string &msg,
                const std::string &shader = "",
                const std::string &compileError = "");
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
