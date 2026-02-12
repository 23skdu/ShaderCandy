//
//  DynamicRangeOptimizer.h
//  ShaderCandy
//
//  Content-adaptive tone mapping
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

typedef NS_ENUM(NSInteger, DynamicRangeMode) {
    DynamicRangeModeOff,
    DynamicRangeModeConservative,
    DynamicRangeModeAggressive,
    DynamicRangeModeAuto
};

@interface DynamicRangeOptimizer : NSObject

@property(nonatomic, assign) DynamicRangeMode mode;
@property(nonatomic, assign) float sceneBrightness;
@property(nonatomic, assign) float targetNits;
@property(nonatomic, assign) float kneePoint;
@property(nonatomic, assign) float shoulderPoint;
@property(nonatomic, assign) float shadowDetail;
@property(nonatomic, assign) float highlightDetail;

- (instancetype)initWithDevice:(id<MTLDevice>)device;

- (void)analyzeSceneBrightness:(id<MTLTexture>)frame commandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)applyOptimizationToTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

- (simd_float3)applyLocalToneMapping:(simd_float3)color localLuminance:(float)luminance;
- (float)calculateDynamicExposure:(float)avgLuminance;

- (void)resetAnalysis;

@end
