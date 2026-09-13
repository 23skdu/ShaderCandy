#include "PerformanceMonitor.h"
#include <algorithm>
#include <numeric>

namespace ShaderCandy {

PerformanceMonitor::PerformanceMonitor(size_t historySize)
    : historySize_(historySize), sortedTimes_{} {
  // deque doesn't need reserve
}

PerformanceMonitor::~PerformanceMonitor() = default;

void PerformanceMonitor::beginFrame() {
  if (!enabled_)
    return;
  frameStart_ = std::chrono::high_resolution_clock::now();
}

void PerformanceMonitor::endFrame() {
  if (!enabled_)
    return;

  auto now = std::chrono::high_resolution_clock::now();
  float ms =
      std::chrono::duration<float, std::milli>(now - frameStart_).count();

  lastFrameTime_ = ms;

  // Add to history
  frameTimes_.push_back(ms);
  if (frameTimes_.size() > historySize_) {
    frameTimes_.pop_front();
  }

  sortedDirty_ = true;

  // Count dropped frames (> 33ms = < 30fps)
  if (ms > 33.33f) {
    droppedFrames_++;
  }
}

PerformanceMetrics PerformanceMonitor::getMetrics() const {
  PerformanceMetrics metrics = {};

  if (frameTimes_.empty()) {
    return metrics;
  }

  metrics.frameTimeMs = lastFrameTime_;
  metrics.currentFPS = 1000.0f / lastFrameTime_;
  metrics.averageFPS = getAverageFPS();
  metrics.droppedFrames = droppedFrames_;

  // Calculate min/max
  auto [minIt, maxIt] =
      std::minmax_element(frameTimes_.begin(), frameTimes_.end());
  metrics.minFPS = 1000.0f / (*maxIt);
  metrics.maxFPS = 1000.0f / (*minIt);

  return metrics;
}

float PerformanceMonitor::getAverageFPS() const {
  if (frameTimes_.empty())
    return 0.0f;

  float avgMs = std::accumulate(frameTimes_.begin(), frameTimes_.end(), 0.0f) /
                frameTimes_.size();
  return 1000.0f / avgMs;
}

float PerformanceMonitor::getLastFrameTimeMs() const { return lastFrameTime_; }

float PerformanceMonitor::getP99FrameTimeMs() const {
  if (frameTimes_.empty())
    return 0.0f;

  updateSortedTimes();

  size_t count = std::min(frameTimes_.size(), sortedTimes_.size());
  if (count == 0)
    return 0.0f;

  size_t p99Index = static_cast<size_t>(count * 0.99f);
  p99Index = std::min(p99Index, count - 1);

  return sortedTimes_[p99Index];
}

void PerformanceMonitor::reset() {
  frameTimes_.clear();
  droppedFrames_ = 0;
  lastFrameTime_ = 0.0f;
  sortedDirty_ = true;
}

void PerformanceMonitor::updateSortedTimes() const {
  if (!sortedDirty_)
    return;

  size_t count = std::min(frameTimes_.size(), sortedTimes_.size());
  std::copy_n(frameTimes_.begin(), count, sortedTimes_.begin());
  std::sort(sortedTimes_.begin(), sortedTimes_.begin() + count);

  sortedDirty_ = false;
}

void PerformanceMonitor::calculateAdaptiveRayMarchLoD(
    float thermalLevel, float p99LatencyMs, int &outMaxSteps,
    float &outStepEpsilon, float &outLodScale) {
  // Base configuration for nominal performance (60+ FPS)
  outMaxSteps = 128;
  outStepEpsilon = 0.001f;
  outLodScale = 1.0f;

  if (thermalLevel >= 0.85f || p99LatencyMs > 33.33f) {
    // Critical thermal state or dropped below 30 FPS
    outMaxSteps = 48;
    outStepEpsilon = 0.005f;
    outLodScale = 0.5f;
  } else if (thermalLevel >= 0.66f || p99LatencyMs > 25.0f) {
    // Serious thermal state or dropped below 40 FPS
    outMaxSteps = 64;
    outStepEpsilon = 0.0035f;
    outLodScale = 0.65f;
  } else if (thermalLevel >= 0.33f || p99LatencyMs > 16.67f) {
    // Fair thermal state or slight frame pacing pressure
    outMaxSteps = 96;
    outStepEpsilon = 0.002f;
    outLodScale = 0.85f;
  }
}

float PerformanceMonitor::calculateDynamicResolutionScale(
    float p99LatencyMs, float targetFrameTimeMs) {
  if (p99LatencyMs <= targetFrameTimeMs) {
    return 1.0f;
  }
  float scale = targetFrameTimeMs / p99LatencyMs;
  return std::clamp(scale, 0.5f, 1.0f);
}

} // namespace ShaderCandy
