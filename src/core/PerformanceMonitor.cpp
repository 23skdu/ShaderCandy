#include "PerformanceMonitor.h"
#include <algorithm>
#include <numeric>

namespace ShaderCandy {

PerformanceMonitor::PerformanceMonitor(size_t historySize) 
    : historySize_(historySize) {
    // deque doesn't need reserve
}

PerformanceMonitor::~PerformanceMonitor() = default;

void PerformanceMonitor::beginFrame() {
    if (!enabled_) return;
    frameStart_ = std::chrono::high_resolution_clock::now();
}

void PerformanceMonitor::endFrame() {
    if (!enabled_) return;
    
    auto now = std::chrono::high_resolution_clock::now();
    float ms = std::chrono::duration<float, std::milli>(now - frameStart_).count();
    
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
    auto [minIt, maxIt] = std::minmax_element(frameTimes_.begin(), frameTimes_.end());
    metrics.minFPS = 1000.0f / (*maxIt);
    metrics.maxFPS = 1000.0f / (*minIt);
    
    return metrics;
}

float PerformanceMonitor::getAverageFPS() const {
    if (frameTimes_.empty()) return 0.0f;
    
    float avgMs = std::accumulate(frameTimes_.begin(), frameTimes_.end(), 0.0f) 
                  / frameTimes_.size();
    return 1000.0f / avgMs;
}

float PerformanceMonitor::getLastFrameTimeMs() const {
    return lastFrameTime_;
}

float PerformanceMonitor::getP99FrameTimeMs() const {
    if (frameTimes_.empty()) return 0.0f;
    
    updateSortedTimes();
    
    size_t p99Index = static_cast<size_t>(sortedTimes_.size() * 0.99f);
    p99Index = std::min(p99Index, sortedTimes_.size() - 1);
    
    return sortedTimes_[p99Index];
}

void PerformanceMonitor::reset() {
    frameTimes_.clear();
    droppedFrames_ = 0;
    lastFrameTime_ = 0.0f;
    sortedDirty_ = true;
}

void PerformanceMonitor::updateSortedTimes() const {
    if (!sortedDirty_) return;
    
    size_t count = std::min(frameTimes_.size(), sortedTimes_.size());
    std::copy_n(frameTimes_.begin(), count, sortedTimes_.begin());
    std::sort(sortedTimes_.begin(), sortedTimes_.begin() + count);
    
    sortedDirty_ = false;
}

} // namespace ShaderCandy
