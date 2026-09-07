//
//  ShaderCandy
//  MultiDisplayManager and HeadlessRenderer Implementation
//

#include "MultiDisplayManager.h"
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <map>

namespace ShaderCandy {

class MultiDisplayManager::Impl {
public:
  std::vector<DisplayInfo> displays;
  std::map<std::string, std::string> displayShaders;
  std::map<std::string, bool> displayEnabled;
  DisplayChangeCallback changeCallback;

  void discoverDisplays() {
    displays.clear();
    // Default primary display definition
    DisplayInfo primary;
    primary.id = "display-0";
    primary.name = "Primary Display";
    primary.x = 0;
    primary.y = 0;
    primary.width = 1920;
    primary.height = 1080;
    primary.refreshRate = 60;
    primary.isPrimary = true;
    primary.scaleFactor = 1.0f;
    displays.push_back(primary);

    displayEnabled[primary.id] = true;
  }
};

MultiDisplayManager &MultiDisplayManager::getInstance() {
  static MultiDisplayManager instance;
  return instance;
}

MultiDisplayManager::MultiDisplayManager() : pImpl(std::make_unique<Impl>()) {
  pImpl->discoverDisplays();
}

MultiDisplayManager::~MultiDisplayManager() = default;

bool MultiDisplayManager::initialize() {
  pImpl->discoverDisplays();
  if (pImpl->changeCallback) {
    pImpl->changeCallback(pImpl->displays);
  }
  return !pImpl->displays.empty();
}

void MultiDisplayManager::shutdown() {
  pImpl->displays.clear();
  pImpl->displayShaders.clear();
  pImpl->displayEnabled.clear();
}

std::vector<DisplayInfo> MultiDisplayManager::getDisplays() const {
  return pImpl->displays;
}

DisplayInfo MultiDisplayManager::getPrimaryDisplay() const {
  for (const auto &d : pImpl->displays) {
    if (d.isPrimary)
      return d;
  }
  if (!pImpl->displays.empty()) {
    return pImpl->displays.front();
  }
  return DisplayInfo{"default", "Default", 0, 0, 1920, 1080, 60, true, 1.0f};
}

DisplayInfo MultiDisplayManager::getDisplay(const std::string &id) const {
  for (const auto &d : pImpl->displays) {
    if (d.id == id)
      return d;
  }
  return getPrimaryDisplay();
}

void MultiDisplayManager::setDisplayShader(const std::string &displayId,
                                          const std::string &shaderName) {
  pImpl->displayShaders[displayId] = shaderName;
}

std::string MultiDisplayManager::getDisplayShader(const std::string &displayId) const {
  auto it = pImpl->displayShaders.find(displayId);
  if (it != pImpl->displayShaders.end()) {
    return it->second;
  }
  return "";
}

void MultiDisplayManager::setDisplayEnabled(const std::string &displayId, bool enabled) {
  pImpl->displayEnabled[displayId] = enabled;
}

bool MultiDisplayManager::isDisplayEnabled(const std::string &displayId) const {
  auto it = pImpl->displayEnabled.find(displayId);
  if (it != pImpl->displayEnabled.end()) {
    return it->second;
  }
  return true;
}

void MultiDisplayManager::setSpanMode(SpanMode mode) {
  spanMode_ = mode;
}

MultiDisplayManager::SpanMode MultiDisplayManager::getSpanMode() const {
  return spanMode_;
}

int MultiDisplayManager::getVirtualWidth() const {
  if (pImpl->displays.empty()) return 1920;
  int minX, minY, maxX, maxY;
  DisplayUtils::getBoundingBox(pImpl->displays, minX, minY, maxX, maxY);
  return std::max(1, maxX - minX);
}

int MultiDisplayManager::getVirtualHeight() const {
  if (pImpl->displays.empty()) return 1080;
  int minX, minY, maxX, maxY;
  DisplayUtils::getBoundingBox(pImpl->displays, minX, minY, maxX, maxY);
  return std::max(1, maxY - minY);
}

float MultiDisplayManager::getVirtualAspectRatio() const {
  int w = getVirtualWidth();
  int h = getVirtualHeight();
  return (h > 0) ? (static_cast<float>(w) / static_cast<float>(h)) : (16.0f / 9.0f);
}

void MultiDisplayManager::virtualToDisplay(float vx, float vy, const std::string &displayId,
                                          float &dx, float &dy) const {
  DisplayInfo d = getDisplay(displayId);
  int vw = getVirtualWidth();
  int vh = getVirtualHeight();

  // Normalized virtual coordinates [0, 1] to absolute pixels
  float absX = vx * vw;
  float absY = vy * vh;

  // Local display normalized coordinates
  dx = (d.width > 0) ? ((absX - d.x) / d.width) : 0.0f;
  dy = (d.height > 0) ? ((absY - d.y) / d.height) : 0.0f;
}

void MultiDisplayManager::displayToVirtual(const std::string &displayId, float dx, float dy,
                                          float &vx, float &vy) const {
  DisplayInfo d = getDisplay(displayId);
  int vw = getVirtualWidth();
  int vh = getVirtualHeight();

  float absX = d.x + dx * d.width;
  float absY = d.y + dy * d.height;

  vx = (vw > 0) ? (absX / vw) : 0.0f;
  vy = (vh > 0) ? (absY / vh) : 0.0f;
}

void MultiDisplayManager::synchronizeTime(double time) {
  syncTime_ = time;
}

double MultiDisplayManager::getSynchronizedTime() const {
  return syncTime_;
}

void MultiDisplayManager::setDisplayChangeCallback(DisplayChangeCallback callback) {
  pImpl->changeCallback = callback;
}

// ---------------------------------------------------------------------------
// HeadlessRenderer Implementation
// ---------------------------------------------------------------------------

class HeadlessRenderer::Impl {
public:
  std::vector<uint8_t> frameBuffer;
  ProgressCallback progressCallback;
  int selectedGPU = 0;
};

HeadlessRenderer::HeadlessRenderer() : pImpl(std::make_unique<Impl>()) {}
HeadlessRenderer::~HeadlessRenderer() = default;

bool HeadlessRenderer::initialize(int width, int height) {
  width_ = width;
  height_ = height;
  totalFrames_ = static_cast<int>(duration_ * fps_);
  currentFrame_ = 0;
  pImpl->frameBuffer.resize(width * height * 4, 0);
  return true;
}

void HeadlessRenderer::shutdown() {
  pImpl->frameBuffer.clear();
  currentFrame_ = 0;
}

void HeadlessRenderer::setShader(const std::string &shaderName) {
  currentShader_ = shaderName;
}

void HeadlessRenderer::setDuration(float seconds) {
  duration_ = seconds;
  totalFrames_ = static_cast<int>(duration_ * fps_);
}

void HeadlessRenderer::setFPS(int fps) {
  fps_ = fps;
  totalFrames_ = static_cast<int>(duration_ * fps_);
}

void HeadlessRenderer::setOutputFormat(const std::string &format) {
  outputFormat_ = format;
}

bool HeadlessRenderer::renderToFile(const std::string &outputPath) {
  beginRender();
  auto buffer = renderToBuffer(0);
  endRender();

  std::ofstream out(outputPath, std::ios::binary);
  if (!out) return false;

  // Simple uncompressed PPM fallback for raw frames
  out << "P6\n" << width_ << " " << height_ << "\n255\n";
  for (size_t i = 0; i < buffer.size(); i += 4) {
    out.put(static_cast<char>(buffer[i]));     // R
    out.put(static_cast<char>(buffer[i + 1])); // G
    out.put(static_cast<char>(buffer[i + 2])); // B
  }
  return true;
}

std::vector<uint8_t> HeadlessRenderer::renderToBuffer(int frame) {
  if (pImpl->frameBuffer.empty()) {
    pImpl->frameBuffer.resize(width_ * height_ * 4, 0);
  }
  // Generate a test visual gradient based on frame number
  for (int y = 0; y < height_; ++y) {
    for (int x = 0; x < width_; ++x) {
      size_t idx = (y * width_ + x) * 4;
      pImpl->frameBuffer[idx + 0] = static_cast<uint8_t>((x * 255) / std::max(1, width_));
      pImpl->frameBuffer[idx + 1] = static_cast<uint8_t>((y * 255) / std::max(1, height_));
      pImpl->frameBuffer[idx + 2] = static_cast<uint8_t>((frame * 10) % 256);
      pImpl->frameBuffer[idx + 3] = 255;
    }
  }
  return pImpl->frameBuffer;
}

void HeadlessRenderer::beginRender() {
  currentFrame_ = 0;
}

bool HeadlessRenderer::renderFrame() {
  if (isFinished()) return false;
  renderToBuffer(currentFrame_);
  currentFrame_++;
  if (pImpl->progressCallback) {
    pImpl->progressCallback(currentFrame_, totalFrames_);
  }
  return true;
}

bool HeadlessRenderer::isFinished() const {
  return currentFrame_ >= totalFrames_;
}

void HeadlessRenderer::endRender() {
  currentFrame_ = totalFrames_;
}

void HeadlessRenderer::setProgressCallback(ProgressCallback callback) {
  pImpl->progressCallback = callback;
}

bool HeadlessRenderer::startVideoEncoding(const std::string &, int) {
  return true;
}

bool HeadlessRenderer::encodeFrame(const std::vector<uint8_t> &) {
  return true;
}

void HeadlessRenderer::finishVideoEncoding() {}

void HeadlessRenderer::setGPUDevice(int deviceIndex) {
  pImpl->selectedGPU = deviceIndex;
}

std::vector<std::string> HeadlessRenderer::getAvailableGPUs() const {
  return {"Default GPU", "Integrated GPU"};
}

// ---------------------------------------------------------------------------
// DisplayUtils Implementation
// ---------------------------------------------------------------------------

namespace DisplayUtils {

int getOptimalTextureSize(int displayWidth, int displayHeight, float quality) {
  int maxDim = std::max(displayWidth, displayHeight);
  int scaled = static_cast<int>(maxDim * quality);
  // Round up to nearest power of 2 or multiple of 16
  return std::max(256, (scaled + 15) & ~15);
}

bool areDisplaysContiguous(const std::vector<DisplayInfo> &displays) {
  if (displays.size() <= 1) return true;
  for (size_t i = 0; i < displays.size(); ++i) {
    bool adjacent = false;
    for (size_t j = 0; j < displays.size(); ++j) {
      if (i == j) continue;
      // Check horizontal or vertical adjacency
      if ((displays[i].x + displays[i].width == displays[j].x ||
           displays[j].x + displays[j].width == displays[i].x) &&
          (displays[i].y < displays[j].y + displays[j].height &&
           displays[i].y + displays[i].height > displays[j].y)) {
        adjacent = true;
        break;
      }
    }
    if (!adjacent && displays.size() > 1) {
      return false;
    }
  }
  return true;
}

void getBoundingBox(const std::vector<DisplayInfo> &displays, int &minX,
                    int &minY, int &maxX, int &maxY) {
  if (displays.empty()) {
    minX = minY = 0;
    maxX = 1920;
    maxY = 1080;
    return;
  }
  minX = displays[0].x;
  minY = displays[0].y;
  maxX = displays[0].x + displays[0].width;
  maxY = displays[0].y + displays[0].height;

  for (size_t i = 1; i < displays.size(); ++i) {
    minX = std::min(minX, displays[i].x);
    minY = std::min(minY, displays[i].y);
    maxX = std::max(maxX, displays[i].x + displays[i].width);
    maxY = std::max(maxY, displays[i].y + displays[i].height);
  }
}

bool hasConfigurationChanged(const std::vector<DisplayInfo> &oldConfig,
                             const std::vector<DisplayInfo> &newConfig) {
  if (oldConfig.size() != newConfig.size()) return true;
  for (size_t i = 0; i < oldConfig.size(); ++i) {
    if (oldConfig[i].id != newConfig[i].id ||
        oldConfig[i].x != newConfig[i].x ||
        oldConfig[i].y != newConfig[i].y ||
        oldConfig[i].width != newConfig[i].width ||
        oldConfig[i].height != newConfig[i].height ||
        oldConfig[i].refreshRate != newConfig[i].refreshRate ||
        oldConfig[i].scaleFactor != newConfig[i].scaleFactor) {
      return true;
    }
  }
  return false;
}

} // namespace DisplayUtils

} // namespace ShaderCandy
