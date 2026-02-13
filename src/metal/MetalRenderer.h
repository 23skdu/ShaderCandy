//
//  MetalRenderer.h
//  ShaderCandy
//
//  Unified Metal Renderer - Single source of truth for all Metal operations
//

#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>

#include "../core/ShaderInterop.h"
#import "HDRPipeline.h"

@class MetalResourcePool;
@class MTLPerformanceReporter;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Error Handling

typedef NS_ENUM(NSInteger, MetalRendererErrorCode) {
  MetalRendererErrorCodeNone = 0,
  MetalRendererErrorCodeDeviceCreationFailed,
  MetalRendererErrorCodeCommandQueueFailed,
  MetalRendererErrorCodeShaderCompilationFailed,
  MetalRendererErrorCodePipelineCreationFailed,
  MetalRendererErrorCodeTextureCreationFailed,
  MetalRendererErrorCodeDeviceLost,
  MetalRendererErrorCodeResourceExhausted,
  MetalRendererErrorCodeInvalidState,
};

@interface MetalRendererError : NSObject

@property(nonatomic, readonly) MetalRendererErrorCode code;
@property(nonatomic, readonly, copy) NSString *message;
@property(nonatomic, readonly, copy, nullable) NSString *shaderName;
@property(nonatomic, readonly, copy, nullable) NSString *compilerError;
@property(nonatomic, readonly) NSInteger lineNumber;
@property(nonatomic, readonly) NSDate *timestamp;

+ (instancetype)errorWithCode:(MetalRendererErrorCode)code
                      message:(NSString *)message;

+ (instancetype)shaderErrorWithMessage:(NSString *)message
                         compilerError:(nullable NSString *)compilerError
                            shaderName:(nullable NSString *)shaderName
                            lineNumber:(NSInteger)lineNumber;

@end

#pragma mark - GPU Family Detection

typedef NS_ENUM(NSInteger, MetalGPUFamily) {
  MetalGPUFamilyUnknown = 0,
  MetalGPUFamilyApple1, // All Apple Silicon
  MetalGPUFamilyApple2, // A7-A11
  MetalGPUFamilyApple3, // A12+ with enhanced features
  MetalGPUFamilyMac1,   // Intel/AMD via Rosetta or discrete
  MetalGPUFamilyMac2,   // Modern Mac GPUs
};

@interface MetalDeviceInfo : NSObject

@property(nonatomic, strong, readonly) id<MTLDevice> device;
@property(nonatomic, strong, readonly) NSString *name;
@property(nonatomic, readonly) MetalGPUFamily family;
@property(nonatomic, readonly) NSUInteger maxThreadsPerThreadgroup;
@property(nonatomic, readonly) BOOL supportsTileShaders;
@property(nonatomic, readonly) BOOL supportsSimdGroups;
@property(nonatomic, readonly) BOOL supportsMeshShaders;
@property(nonatomic, readonly) NSUInteger recommendedMaxWorkingSetSize;
@property(nonatomic, readonly) BOOL isLowPower;
@property(nonatomic, readonly) BOOL isHeadless;

@end

#pragma mark - Performance Metrics

@interface MetalPerformanceMetrics : NSObject

@property(nonatomic, assign) double currentFPS;
@property(nonatomic, assign) double averageFPS;
@property(nonatomic, assign) double minFPS;
@property(nonatomic, assign) double maxFPS;
@property(nonatomic, assign) double frameTimeMs;
@property(nonatomic, assign) double gpuTimeMs;
@property(nonatomic, assign) double cpuTimeMs;
@property(nonatomic, assign) NSUInteger droppedFrames;
@property(nonatomic, assign) NSUInteger memoryUsageBytes;

@end

#pragma mark - Pipeline State

@interface MetalPipelineState : NSObject

@property(nonatomic, strong) id<MTLRenderPipelineState> renderPipeline;
@property(nonatomic, strong, nullable) id<MTLRenderPipelineState>
    simulationPipeline;
@property(nonatomic, strong, nullable) id<MTLComputePipelineState>
    computePipeline;
@property(nonatomic, strong, nullable) id<MTLRenderPipelineState>
    particleRenderPipeline;
@property(nonatomic, strong, readonly) NSString *shaderName;
@property(nonatomic, readonly) NSDate *createdAt;

- (instancetype)initWithShaderName:(NSString *)shaderName;

@end

#pragma mark - Render Resources

@interface MetalRenderResources : NSObject

@property(nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property(nonatomic, strong) id<MTLBuffer> indexBuffer;
@property(nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property(nonatomic, strong) id<MTLTexture> sceneTexture;
@property(nonatomic, strong) id<MTLTexture> simulationTextureA;
@property(nonatomic, strong) id<MTLTexture> simulationTextureB;
@property(nonatomic, strong) id<MTLTexture> bloomTextureA;
@property(nonatomic, strong) id<MTLTexture> bloomTextureB;
@property(nonatomic, strong, nullable) id<MTLBuffer> particleBufferA;
@property(nonatomic, strong, nullable) id<MTLBuffer> particleBufferB;
@property(nonatomic, strong) id<MTLSamplerState> samplerState;
@property(nonatomic, strong, nullable) id<MTLRenderPipelineState>
    debugOverlayPipeline;
@property(nonatomic, strong, nullable) id<MTLTexture> mainTexture;
@property(nonatomic, assign) CGSize viewportSize;
@property(nonatomic, assign) NSInteger simulationTextureSize;

@end

#pragma mark - Bloom Configuration

typedef NS_ENUM(NSInteger, MetalBloomQuality) {
  MetalBloomQualityLow = 0,
  MetalBloomQualityMedium,
  MetalBloomQualityHigh,
  MetalBloomQualityUltra,
};

@interface MetalBloomConfig : NSObject

@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, assign) MetalBloomQuality quality;
@property(nonatomic, assign) float intensity;
@property(nonatomic, assign) float threshold;
@property(nonatomic, assign) NSInteger blurRadius;

+ (instancetype)defaultConfig;

@end

#pragma mark - Particle Configuration

@interface MetalParticleConfig : NSObject

@property(nonatomic, assign) NSInteger count;
@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, assign) float gravity;
@property(nonatomic, assign) float speed;

@end

#pragma mark - Main Renderer

@protocol MetalRendererDelegate <NSObject>

@optional
- (void)metalRenderer:(id)renderer
    didEncounterError:(MetalRendererError *)error;
- (void)metalRenderer:(id)renderer
     didUpdateMetrics:(MetalPerformanceMetrics *)metrics;
- (void)metalRenderer:(id)renderer
    didReloadShadersWithName:(NSString *)shaderName;

@end

@interface MetalRenderer : NSObject

#pragma mark - Properties

@property(nonatomic, strong, readonly, nullable) id<MTLDevice> device;
@property(nonatomic, strong, readonly, nullable) id<MTLCommandQueue>
    commandQueue;
@property(nonatomic, strong, readonly) MetalResourcePool *resourcePool;
@property(nonatomic, strong, readonly) MetalDeviceInfo *deviceInfo;
@property(nonatomic, strong, readonly) MetalRenderResources *resources;
@property(nonatomic, strong, readonly) MetalPerformanceMetrics *metrics;
@property(nonatomic, strong, readonly, nullable)
    MetalPipelineState *currentPipeline;
@property(nonatomic, strong, readonly) MetalBloomConfig *bloomConfig;
@property(nonatomic, strong, readonly) MetalParticleConfig *particleConfig;

@property(nonatomic, assign) BOOL developmentMode;
@property(nonatomic, assign) BOOL hotReloadEnabled;
@property(nonatomic, assign) float preferredFPS;
@property(nonatomic, assign) BOOL audioReactivityEnabled;
@property(nonatomic, assign) BOOL showDebugOverlay;
@property(nonatomic, assign) BOOL hdrEnabled;
@property(nonatomic, assign) ToneMappingOperator toneMapping;
@property(nonatomic, assign) float maxBrightness;
@property(nonatomic, assign) BOOL neuralStyleEnabled;
@property(nonatomic, assign) float styleStrength;
@property(nonatomic, copy, nullable) NSString *currentNeuralStyle;
@property(nonatomic, assign) BOOL autoScalingEnabled;
@property(nonatomic, assign) float autoScaleFPSThreshold;
@property(nonatomic, strong, readonly)
    MTLPerformanceReporter *performanceReporter;
@property(nonatomic, assign, nullable) id<MetalRendererDelegate> delegate;

#pragma mark - Frame Synchronization & Display

// Frame pacing and synchronization
@property(nonatomic, assign) BOOL adaptiveSyncEnabled;
@property(nonatomic, assign) BOOL framePacingEnabled;
@property(nonatomic, assign) NSTimeInterval targetFrameTime;
@property(nonatomic, assign, readonly) NSTimeInterval lastFrameTime;

// Ultra-high resolution support
@property(nonatomic, assign) BOOL dynamicResolutionEnabled;
@property(nonatomic, assign) float resolutionScale;
@property(nonatomic, assign) CGFloat maxTextureDimension;

// Memory management
@property(nonatomic, assign) NSUInteger maxMemoryBudgetBytes;
@property(nonatomic, assign, readonly) NSUInteger currentMemoryUsageBytes;
@property(nonatomic, assign) BOOL aggressiveMemoryPurge;

// Performance states
@property(nonatomic, assign, readonly) BOOL isThermalThrottling;
@property(nonatomic, assign, readonly) float thermalLevel;

// Transition state
@property(nonatomic, readonly) BOOL isTransitioning;
@property(nonatomic, readonly) float transitionAlpha;
@property(nonatomic, strong, readonly, nullable)
    MetalPipelineState *previousPipeline;

#pragma mark - Initialization

+ (nullable instancetype)rendererWithDevice:(nullable id<MTLDevice>)device
                                      error:(NSError **)error;

- (BOOL)initializeWithDevice:(nullable id<MTLDevice>)device
                       error:(NSError **)error;

- (void)shutdown;

#pragma mark - Device Management

- (void)handleDeviceLoss;
- (BOOL)recoverWithDevice:(id<MTLDevice>)device error:(NSError **)error;

#pragma mark - Shader Management

- (BOOL)loadShaderWithName:(NSString *)name error:(NSError **)error;

- (BOOL)reloadCurrentShader:(NSError **)error;

- (NSArray<NSString *> *)availableShaderNames;

- (BOOL)setActiveShader:(NSString *)name error:(NSError **)error;

- (BOOL)transitionToShaderNamed:(NSString *)name
                       duration:(NSTimeInterval)duration
                          error:(NSError **)error;

@property(nonatomic, strong, readonly, nullable) NSString *activeShaderName;

#pragma mark - Pipeline Management

- (nullable MetalPipelineState *)createPipelineForShader:(NSString *)name
                                                   error:(NSError **)error;

- (void)prewarmPipelinesForShaders:(NSArray<NSString *> *)shaders;

#pragma mark - Rendering

- (void)updateUniformsWithTime:(NSTimeInterval)time
                 mousePosition:(NSPoint)mousePos
                  mouseButtons:(NSInteger)buttons
                         speed:(float)speed
                     intensity:(float)intensity
                       gravity:(float)gravity
                        height:(CGFloat)height;

- (void)renderToDrawable:(id<CAMetalDrawable>)drawable
    renderPassDescriptor:(MTLRenderPassDescriptor *)descriptor;

#pragma mark - Viewport

- (void)setViewportSize:(CGSize)size;

#pragma mark - Bloom

- (void)setBloomEnabled:(BOOL)enabled;
- (void)setBloomQuality:(MetalBloomQuality)quality;
- (void)setBloomIntensity:(float)intensity;

#pragma mark - Particles

- (void)setParticlesEnabled:(BOOL)enabled;
- (void)setParticleCount:(NSInteger)count;
- (void)setParticleGravity:(float)gravity;

#pragma mark - Audio
- (void)setAudioReactivityEnabled:(BOOL)enabled;

#pragma mark - Performance

- (void)beginFrame;
- (void)endFrame;

- (nullable MetalPerformanceMetrics *)getMetrics;

- (void)resetMetrics;

#pragma mark - Debug

- (void)captureGPUFrame;

- (void)writeFailedShaderToFile:(NSString *)source
                       fileName:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END
