//
//  VulkanRenderer.h
//  ShaderCandy
//
//  Vulkan backend renderer - research scope for HDR on Linux
//  Requires: VK_KHR_swapchain, VK_EXT_swapchain_colorspace
//

#ifndef VULKAN_RENDERER_H
#define VULKAN_RENDERER_H

#include <cstdint>
#include <string>
#include <vector>
#include <unordered_map>

namespace ShaderCandy {
namespace Platform {
namespace Linux {

enum class VulkanToneMapping {
  None = 0,
  ACES,
  Reinhard,
  Filmic,
  Hable
};

enum class VulkanErrorCode {
  None = 0,
  InstanceCreationFailed,
  DeviceNotFound,
  ShaderCompilationFailed,
  PipelineCreationFailed,
  SwapchainCreationFailed,
  OutOfMemory,
  InvalidState
};

struct VulkanPerformanceMetrics {
  double currentFPS = 0.0;
  double averageFPS = 0.0;
  double frameTimeMs = 0.0;
  double gpuTimeMs = 0.0;
  uint32_t droppedFrames = 0;
  uint32_t memoryUsageBytes = 0;
};

class VulkanRenderer {
public:
  VulkanRenderer();
  ~VulkanRenderer();

  bool initialize();
  void shutdown();

  bool isInitialized() const { return initialized_; }

  void render(float time);

  void resize(int width, int height);

  void setSpeed(float speed) { speed_ = speed; }
  void setIntensity(float intensity) { intensity_ = intensity; }
  void setHDREnabled(bool enabled) { hdrEnabled_ = enabled; }
  bool isHDREnabled() const { return hdrEnabled_; }
  void setToneMapping(VulkanToneMapping toneMapping) { toneMapping_ = toneMapping; }

  VulkanPerformanceMetrics getMetrics();

  std::vector<std::string> availableShaderNames() const;
  bool setActiveShader(const std::string &name);

private:
  bool initialized_ = false;
  bool hdrEnabled_ = false;

  float speed_ = 1.0f;
  float intensity_ = 1.0f;
  VulkanToneMapping toneMapping_ = VulkanToneMapping::ACES;

  struct ShaderModule {
    void *module = nullptr;
    std::string name;
  };

  std::unordered_map<std::string, ShaderModule> shaderModules_;
  void *currentPipeline_ = nullptr;
  std::string currentShader_;

  VulkanPerformanceMetrics metrics_;

  int width_ = 0;
  int height_ = 0;
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy

#endif // VULKAN_RENDERER_H