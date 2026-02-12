//
//  MTLPerformanceReporter.mm
//  ShaderCandy
//

#import "MTLPerformanceReporter.h"
#import <QuartzCore/QuartzCore.h>

@implementation GPUFrameStats
@end

@interface MTLPerformanceReporter () {
  NSDate *_frameStartTime;
  uint64_t _cpuStartTime;
  double _lastGPUTime;
  double _lastCPUTime;
  double _lastFrameTime;

  NSMutableArray<NSNumber *> *_gpuTimeHistory;
  NSMutableArray<NSNumber *> *_frameTimeHistory;

  CFTimeInterval _lastFPSUpdate;
  NSUInteger _frameCount;
  double _currentFPS;
}
@end

@implementation MTLPerformanceReporter

- (instancetype)initWithDevice:(id<MTLDevice>)device {
  self = [super init];
  if (self) {
    _device = device;
    _gpuTimeHistory = [NSMutableArray array];
    _frameTimeHistory = [NSMutableArray array];
    _supportsCounters = [device supportsFamily:MTLGPUFamilyApple1] ||
                        [device supportsFamily:MTLGPUFamilyMac2];
  }
  return self;
}

- (void)beginFrame {
  _frameStartTime = [NSDate date];
  _cpuStartTime = CACurrentMediaTime();
}

- (void)endFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
  double cpuEndTime = CACurrentMediaTime();
  _lastCPUTime = (cpuEndTime - _cpuStartTime) * 1000.0;

  uint64_t __block gpuStart;
  [commandBuffer addScheduledHandler:^(id<MTLCommandBuffer> _Nonnull buf) {
    gpuStart = CACurrentMediaTime();
  }];

  __weak typeof(self) weakSelf = self;
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buf) {
    double gpuEnd = CACurrentMediaTime();
    double gpuDurationMs = (buf.GPUEndTime - buf.GPUStartTime) * 1000.0;

    // If system doesn't provide accurate GPU timestamps, fallback to host-side
    // delta
    if (gpuDurationMs <= 0) {
      gpuDurationMs = (gpuEnd - gpuStart) * 1000.0;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf updateGPUTime:gpuDurationMs];
    });
  }];

  _lastFrameTime =
      [[NSDate date] timeIntervalSinceDate:_frameStartTime] * 1000.0;
  [_frameTimeHistory addObject:@(_lastFrameTime)];
  if (_frameTimeHistory.count > 60)
    [_frameTimeHistory removeObjectAtIndex:0];

  _frameCount++;
  CFTimeInterval now = CACurrentMediaTime();
  if (now - _lastFPSUpdate >= 1.0) {
    _currentFPS = _frameCount / (now - _lastFPSUpdate);
    _frameCount = 0;
    _lastFPSUpdate = now;
  }
}

- (void)updateGPUTime:(double)gpuTimeMs {
  _lastGPUTime = gpuTimeMs;
  [_gpuTimeHistory addObject:@(gpuTimeMs)];
  if (_gpuTimeHistory.count > 60)
    [_gpuTimeHistory removeObjectAtIndex:0];
}

- (GPUFrameStats *)latestStats {
  GPUFrameStats *stats = [[GPUFrameStats alloc] init];
  stats.gpuTimeMs = _lastGPUTime;
  stats.cpuTimeMs = _lastCPUTime;
  stats.frameTimeMs = _lastFrameTime;
  return stats;
}

- (double)averageGPUTimeMs {
  if (_gpuTimeHistory.count == 0)
    return 0;
  double sum = 0;
  for (NSNumber *n in _gpuTimeHistory)
    sum += n.doubleValue;
  return sum / _gpuTimeHistory.count;
}

- (double)currentFPS {
  return _currentFPS;
}

@end
