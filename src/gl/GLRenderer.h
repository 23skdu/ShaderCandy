//
//  GLRenderer.h
//  ShaderCandy
//
//  Linux OpenGL Renderer - Matches MetalRenderer interface
//

#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include "../core/ShaderInterop.h"
#include "GLRendererTypes.h"
#include "UniformUploader.h"

namespace ShaderCandy {
namespace Platform {
namespace Linux {

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
  const std::string &activeShaderName() const { return currentShader_; }

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
  bool initToneMapping();
  void renderToneMap();

  // Performance
  GLPerformanceMetrics getMetrics();
  void resetMetrics();

  // Hot reload
  void setHotReloadEnabled(bool enabled) { hotReloadEnabled_ = enabled; }
  bool isHotReloadEnabled() const { return hotReloadEnabled_; }
  void checkForShaderReload();

  // Error handling
  const GLRendererError &getLastError() const { return lastError_; }
  void clearError() {
    lastError_ = GLRendererError();
  }
  void setErrorCallback(std::function<void(const GLRendererError &)> cb) {
    errorCallback_ = std::move(cb);
  }

  // Shader change callback
  void setShaderChangedCallback(std::function<void(const std::string &)> cb) {
    shaderChangedCallback_ = std::move(cb);
  }

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

  // Tone mapping (HDR -> SDR)
  unsigned int toneMapFBO_ = 0;
  unsigned int toneMapTexture_ = 0;
  unsigned int toneMapProgram_ = 0;
  unsigned int toneMapQuadVAO_ = 0;
  unsigned int toneMapQuadVBO_ = 0;

  // Quad VAO/VBO
  void setupQuad();

  // Shader compilation
  unsigned int compileShader(const std::string &source, unsigned int type);
  unsigned int linkProgram(unsigned int vs, unsigned int fs);
  std::string loadShaderSource(const std::string &path);

  // Uniforms
  Uniforms uniforms_;
  int uniformsLocation_ = -1;
  UniformUploader uniformUploader_;

  // Audio
  bool audioReactivityEnabled_ = false;

  // HDR
  bool hdrEnabled_ = false;
  GLToneMapping toneMapping_ = GLToneMapping::ACES;

  // Particles
  struct Particle {
    float x, y;
    float vx, vy;
    float life;
    float maxLife;
  };
  std::vector<Particle> particles_;
  unsigned int particleVBO_ = 0;
  unsigned int particleVAO_ = 0;
  GLParticleConfig particleConfig_;

  void initParticles();
  void updateParticles(float deltaTime);
  void renderParticles();

  // Performance tracking
  GLPerformanceMetrics metrics_;
  double lastFrameTime_ = 0.0;
  double fpsAccumulator_ = 0.0;
  int frameCount_ = 0;

  // Hot reload
  bool hotReloadEnabled_ = true;
  std::unordered_map<std::string, double> shaderModTimes_;
  std::unordered_map<std::string, std::string> shaderPaths_;

  // Error state
  GLRendererError lastError_;

  // Post-processing FBO
  void initPostProcessingFBO();
  void initBloom();
  void renderBloom();

  int renderWidth_ = 0;
  int renderHeight_ = 0;

  // Blit program (passthrough for FBO → screen when HDR off)
  unsigned int blitProgram_ = 0;

  // Video encoding state
  FILE *ffmpegProcess_ = nullptr;
  bool encodingVideo_ = false;

  // Callbacks
  std::function<void(const std::string &)> shaderChangedCallback_;
  std::function<void(const GLRendererError &)> errorCallback_;

  void setError(GLRendererErrorCode code, const std::string &msg,
                const std::string &shader = "",
                const std::string &compileError = "");

  // Shader file watching (inotify)
  void startFileWatcher();
  void stopFileWatcher();
  std::thread fileWatcherThread_;
  std::atomic<bool> fileWatcherRunning_{false};
  std::unordered_map<std::string, int> watchDescriptors_;
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
