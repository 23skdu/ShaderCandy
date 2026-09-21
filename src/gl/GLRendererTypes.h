#pragma once

#include <string>

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
  GLRendererErrorCode code = GLRendererErrorCode::None;
  std::string message;
  std::string shaderName;
  std::string compilerError;
  int lineNumber = 0;

  GLRendererError() = default;
  GLRendererError(GLRendererErrorCode c, const std::string &m,
                  const std::string &s, const std::string &e, int l)
      : code(c), message(m), shaderName(s), compilerError(e), lineNumber(l) {}
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

enum class GLTransitionType {
  None = 0,
  Crossfade,
  Dissolve,
  WipeLeft,
  WipeRight,
  WipeUp,
  WipeDown,
  ZoomIn,
  ZoomOut,
  SpinClockwise,
  SpinCounterClockwise
};

enum class GLEasingFunction {
  Linear = 0,
  EaseIn,
  EaseOut,
  EaseInOut,
  CubicIn,
  CubicOut,
  CubicInOut,
  ExponentialIn,
  ExponentialOut,
  ExponentialInOut
};

struct GLTransitionConfig {
  GLTransitionType type = GLTransitionType::Crossfade;
  GLEasingFunction easing = GLEasingFunction::EaseInOut;
  float duration = 2.0f;
  bool enabled = true;
};

struct GLPostProcessConfig {
  bool vignetteEnabled = true;
  float vignetteIntensity = 0.3f;
  float vignetteRadius = 0.8f;

  bool chromaticAberrationEnabled = true;
  float chromaticAberrationAmount = 0.003f;

  bool filmGrainEnabled = false;
  float filmGrainIntensity = 0.05f;

  bool crtScanlinesEnabled = false;
  float crtScanlineIntensity = 0.1f;
  float crtScanlineCount = 480.0f;

  float colorTintR = 1.0f;
  float colorTintG = 1.0f;
  float colorTintB = 1.0f;
  bool colorTintEnabled = false;
};

struct GLAdaptiveQualityConfig {
  bool enabled = true;
  float targetFPS = 60.0f;
  float lowFPS = 45.0f;
  float highFPS = 65.0f;
  float minResolutionScale = 0.5f;
  float maxResolutionScale = 1.0f;
  float currentResolutionScale = 1.0f;
  int adaptationSpeed = 2;
  bool thermalThrottlingEnabled = true;
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
