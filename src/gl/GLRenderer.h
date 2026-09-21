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
#include <random>
#include <string>
#include <thread>
#include <unordered_map>
#include <unordered_set>
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
  void setAudioDataArray(const float *audioData, int count);
  void setGravity(float gravity) { uniforms_.gravity = gravity; }

  // Shader Parameters (param1-6, colorPalette, effectFlags)
  void setShaderParam1(float v) { shaderParams_.param1 = v; }
  void setShaderParam2(float v) { shaderParams_.param2 = v; }
  void setShaderParam3(float v) { shaderParams_.param3 = v; }
  void setShaderParam4(float v) { shaderParams_.param4 = v; }
  void setShaderParam5(float v) { shaderParams_.param5 = v; }
  void setShaderParam6(float v) { shaderParams_.param6 = v; }
  void setColorPalette(int v) { shaderParams_.colorPalette = v; }
  void setEffectFlags(int v) { shaderParams_.effectFlags = v; }

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

  // Transitions
  void setTransitionConfig(const GLTransitionConfig &config) {
    transitionConfig_ = config;
  }
  GLTransitionConfig getTransitionConfig() const { return transitionConfig_; }
  bool isTransitioning() const { return inTransition_; }
  float getTransitionProgress() const { return transitionProgress_; }

  void beginTransition(GLTransitionType type, GLEasingFunction easing,
                       float duration);
  void updateTransition(float deltaTime);
  float applyEasing(float t) const;
  void renderTransition(float time);

  // Post-Processing
  void setPostProcessConfig(const GLPostProcessConfig &config) {
    postProcessConfig_ = config;
  }
  GLPostProcessConfig getPostProcessConfig() const {
    return postProcessConfig_;
  }

  // Adaptive Quality
  void setAdaptiveQualityConfig(const GLAdaptiveQualityConfig &config) {
    adaptiveQualityConfig_ = config;
  }
  GLAdaptiveQualityConfig getAdaptiveQualityConfig() const {
    return adaptiveQualityConfig_;
  }

  // Smart Shader Rotation
  void setShuffleMode(bool enabled) { shuffleMode_ = enabled; }
  bool isShuffleMode() const { return shuffleMode_; }
  void setAutoRotate(bool enabled) { autoRotate_ = enabled; }
  bool isAutoRotate() const { return autoRotate_; }
  void setTimePerShader(float seconds) { timePerShader_ = seconds; }
  float getTimePerShader() const { return timePerShader_; }
  std::string getNextShaderName() const;

  // Favorites / Skip list
  void addFavorite(const std::string &name);
  void removeFavorite(const std::string &name);
  bool isFavorite(const std::string &name) const;
  void addSkip(const std::string &name);
  void removeSkip(const std::string &name);
  bool isSkipped(const std::string &name) const;

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

  // Second FBO for ping-pong post-processing
  unsigned int fbo2_ = 0;
  unsigned int fboTexture2_ = 0;

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

  // Post-processing shader programs
  unsigned int postProcessProgram_ = 0;

  // Quad VAO/VBO
  void setupQuad();

  // Shader compilation
  unsigned int compileShader(const std::string &source, unsigned int type);
  unsigned int linkProgram(unsigned int vs, unsigned int fs);
  std::string loadShaderSource(const std::string &path);

  // Uniforms
  Uniforms uniforms_;
  ShaderParams shaderParams_;
  int uniformsLocation_ = -1;
  UniformUploader uniformUploader_;

  // Audio
  bool audioReactivityEnabled_ = false;

  // HDR
  bool hdrEnabled_ = false;
  GLToneMapping toneMapping_ = GLToneMapping::ACES;

  // Transitions
  GLTransitionConfig transitionConfig_;
  bool inTransition_ = false;
  float transitionProgress_ = 0.0f;
  float transitionTime_ = 0.0f;
  std::string transitionFromShader_;
  std::string transitionToShader_;

  // Post-Processing
  GLPostProcessConfig postProcessConfig_;

  // Adaptive Quality
  GLAdaptiveQualityConfig adaptiveQualityConfig_;
  float currentResolutionScale_ = 1.0f;

  // Smart Shader Rotation
  bool shuffleMode_ = false;
  bool autoRotate_ = true;
  float timePerShader_ = 60.0f;
  std::vector<std::string> shaderHistory_;
  int historyIndex_ = -1;
  std::mt19937 rng_;

  // Favorites / Skip
  std::unordered_set<std::string> favorites_;
  std::unordered_set<std::string> skipList_;

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
  int droppedFrameCount_ = 0;

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
  void initPostProcessShader();
  void renderPostProcess();

  int renderWidth_ = 0;
  int renderHeight_ = 0;

  // Blit program (passthrough for FBO -> screen when HDR off)
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
