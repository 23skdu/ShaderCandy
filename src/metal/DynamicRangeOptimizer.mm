//
//  DynamicRangeOptimizer.mm
//  ShaderCandy
//
//  Dynamic range optimization implementation
//

#import "DynamicRangeOptimizer.h"

@interface DynamicRangeOptimizer ()

@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLComputePipelineState> analysisPipeline;
@property(nonatomic, strong) id<MTLComputePipelineState> optimizationPipeline;
@property(nonatomic, strong) id<MTLBuffer> histogramBuffer;
@property(nonatomic, assign) float avgLuminance;
@property(nonatomic, assign) float maxLuminance;
@property(nonatomic, strong) id<MTLLibrary> shaderLibrary;

@end

@implementation DynamicRangeOptimizer

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _mode = DynamicRangeModeAuto;
        _targetNits = 1000.0;
        _kneePoint = 0.5;
        _shoulderPoint = 0.9;
        _shadowDetail = 0.5;
        _highlightDetail = 0.5;
        _avgLuminance = 0.5;
        _maxLuminance = 1.0;

        [self setupShaders];
        [self setupBuffers];
    }
    return self;
}

- (void)setupShaders {
    NSError *error = nil;
    _shaderLibrary = [_device newDefaultLibrary];

    if (!_shaderLibrary) {
        // Create shaders from source
        NSString *shaderSource = @"#include <metal_stdlib>\n"
            "using namespace metal;\n"
            "kernel void analyzeBrightness(texture2d<float, access::read> input [[texture(0)]],\n"
            "                              device atomic_float *avgLum [[buffer(0)]],\n"
            "                              device atomic_float *maxLum [[buffer(1)]],\n"
            "                              uint2 gid [[thread_position_in_grid]]) {\n"
            "    float3 color = input.read(gid).rgb;\n"
            "    float lum = dot(color, float3(0.299, 0.587, 0.114));\n"
            "    atomic_fetch_add_explicit(avgLum, lum, memory_order_relaxed);\n"
            "    atomic_fetch_max_explicit(maxLum, lum, memory_order_relaxed);\n"
            "}\n";

        _shaderLibrary = [_device newLibraryWithSource:shaderSource options:nil error:&error];
    }

    id<MTLFunction> analysisFunc = [_shaderLibrary newFunctionWithName:@"analyzeBrightness"];
    if (analysisFunc) {
        _analysisPipeline = [_device newComputePipelineStateWithFunction:analysisFunc error:&error];
    }
}

- (void)setupBuffers {
    _histogramBuffer = [_device newBufferWithLength:sizeof(float) * 256 options:MTLResourceStorageModeShared];
}

- (void)analyzeSceneBrightness:(id<MTLTexture>)frame commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    if (!_analysisPipeline || _mode == DynamicRangeModeOff) return;

    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    [encoder setComputePipelineState:_analysisPipeline];
    [encoder setTexture:frame atIndex:0];

    // Dispatch compute
    MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
    MTLSize threadGroups = MTLSizeMake(
        (frame.width + threadGroupSize.width - 1) / threadGroupSize.width,
        (frame.height + threadGroupSize.height - 1) / threadGroupSize.height,
        1
    );

    [encoder dispatchThreadgroups:threadGroups threadsPerThreadgroup:threadGroupSize];
    [encoder endEncoding];
}

- (void)applyOptimizationToTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    // Apply exposure adjustment based on analysis
    float exposure = [self calculateDynamicExposure:_avgLuminance];

    // Adjust target nits based on mode
    switch (_mode) {
        case DynamicRangeModeConservative:
            _targetNits = 500.0;
            break;
        case DynamicRangeModeAggressive:
            _targetNits = 2000.0;
            break;
        case DynamicRangeModeAuto:
            _targetNits = 1000.0 * (1.0 + _sceneBrightness);
            break;
        default:
            break;
    }
}

- (simd_float3)applyLocalToneMapping:(simd_float3)color localLuminance:(float)luminance {
    // Apply S-curve for local contrast enhancement
    float x = luminance;
    float y;

    if (x < _kneePoint) {
        // Shadow region - lift shadows
        y = x * (1.0 + _shadowDetail * (1.0 - x / _kneePoint));
    } else if (x < _shoulderPoint) {
        // Mid-tone - linear
        y = x;
    } else {
        // Highlight region - compress highlights
        float t = (x - _shoulderPoint) / (1.0 - _shoulderPoint);
        y = _shoulderPoint + t * (1.0 - _shoulderPoint) * (1.0 - _highlightDetail * t);
    }

    // Apply tone mapping to color
    float scale = y / (luminance + 0.001);
    return color * scale;
}

- (float)calculateDynamicExposure:(float)avgLuminance {
    // Target middle gray at 0.18
    float targetLum = 0.18;
    float exposure = log2(targetLum / (avgLuminance + 0.001));

    // Clamp exposure adjustment
    exposure = fmaxf(-2.0, fminf(2.0, exposure));

    return powf(2.0, exposure);
}

- (void)resetAnalysis {
    _avgLuminance = 0.5;
    _maxLuminance = 1.0;
    _sceneBrightness = 0.5;
}

@end
