#pragma once

#include <deque>
#include <chrono>
#include <array>

namespace ShaderCandy {

struct PerformanceMetrics {
    float currentFPS;
    float averageFPS;
    float minFPS;
    float maxFPS;
    float frameTimeMs;
    float gpuTimeMs;
    float cpuTimeMs;
    int droppedFrames;
};

class PerformanceMonitor {
public:
    PerformanceMonitor(size_t historySize = 120); // 2 seconds at 60fps
    ~PerformanceMonitor();
    
    // Call at start of frame
    void beginFrame();
    
    // Call at end of frame
    void endFrame();
    
    // Get current metrics
    PerformanceMetrics getMetrics() const;
    
    // Get rolling average FPS
    float getAverageFPS() const;
    
    // Get last frame time in ms
    float getLastFrameTimeMs() const;
    
    // Get 99th percentile frame time
    float getP99FrameTimeMs() const;
    
    // Reset statistics
    void reset();
    
    // Enable/disable monitoring
    void setEnabled(bool enabled) { enabled_ = enabled; }
    bool isEnabled() const { return enabled_; }

private:
    bool enabled_ = true;
    size_t historySize_;
    
    std::deque<float> frameTimes_;
    std::chrono::high_resolution_clock::time_point frameStart_;
    
    mutable std::array<float, 128> sortedTimes_;
    mutable bool sortedDirty_ = true;
    
    float lastFrameTime_ = 0.0f;
    int droppedFrames_ = 0;
    
    void updateSortedTimes() const;
};

} // namespace ShaderCandy
