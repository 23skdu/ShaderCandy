//
//  MTLPerformanceReporter.h
//  ShaderCandy
//
//  Advanced GPU timing and performance metrics using Metal counter sample
//  buffers.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface GPUFrameStats : NSObject
@property(nonatomic, assign) double gpuTimeMs;
@property(nonatomic, assign) double cpuTimeMs;
@property(nonatomic, assign) double frameTimeMs;
@property(nonatomic, assign) NSUInteger vertexCount;
@property(nonatomic, assign) NSUInteger particleCount;
@end

@interface MTLPerformanceReporter : NSObject

@property(nonatomic, strong, readonly) id<MTLDevice> device;
@property(nonatomic, readonly) BOOL supportsCounters;

- (instancetype)initWithDevice:(id<MTLDevice>)device;

// Timing points
- (void)beginFrame;
- (void)endFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;

// Statistics
- (GPUFrameStats *)latestStats;
- (double)averageGPUTimeMs;
- (double)currentFPS;

@end

NS_ASSUME_NONNULL_END
