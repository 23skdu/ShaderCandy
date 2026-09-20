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

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
