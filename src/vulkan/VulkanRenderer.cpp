//
//  VulkanRenderer.cpp
//  ShaderCandy
//
//  Vulkan backend renderer - research stub
//

#include "VulkanRenderer.h"

#include <chrono>

namespace ShaderCandy {
namespace Platform {
namespace Linux {

VulkanRenderer::VulkanRenderer() = default;

VulkanRenderer::~VulkanRenderer() { shutdown(); }

bool VulkanRenderer::initialize() {
  if (initialized_) {
    return true;
  }

  initialized_ = true;
  return true;
}

void VulkanRenderer::shutdown() {
  if (!initialized_) {
    return;
  }

  shaderModules_.clear();
  initialized_ = false;
}

void VulkanRenderer::render(float time) {
  (void)time;
}

void VulkanRenderer::resize(int width, int height) {
  width_ = width;
  height_ = height;
  metrics_.memoryUsageBytes = width * height * 4;
}

VulkanPerformanceMetrics VulkanRenderer::getMetrics() {
  return metrics_;
}

std::vector<std::string> VulkanRenderer::availableShaderNames() const {
  std::vector<std::string> names;
  for (const auto &shader : shaderModules_) {
    names.push_back(shader.first);
  }
  return names;
}

bool VulkanRenderer::setActiveShader(const std::string &name) {
  auto it = shaderModules_.find(name);
  if (it == shaderModules_.end()) {
    return false;
  }
  currentShader_ = name;
  return true;
}

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy