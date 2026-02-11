//
//  ShaderCandyView.h
//  ShaderCandy
//
//  macOS Screen Saver Implementation
//

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <ScreenSaver/ScreenSaver.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShaderCandyView : ScreenSaverView <MTKViewDelegate>

// Metal objects
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property(nonatomic, strong, nullable) id<MTLRenderPipelineState>
    simulationPipeline;
@property(nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property(nonatomic, strong) id<MTLBuffer> indexBuffer;
@property(nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property(nonatomic, strong) MTKView *mtkView;
@property(nonatomic, strong, nullable) NSWindow *configPanel;

// Shader management
@property(nonatomic, strong) id<MTLLibrary> shaderLibrary;
@property(nonatomic, strong) NSString *currentShaderName;
@property(nonatomic, strong) NSArray<NSString *> *availableShaders;

// Timing
@property(nonatomic, strong) NSDate *startTime;
@property(nonatomic, assign) NSInteger frameCount;

// Configuration
@property(nonatomic, assign) BOOL enableHotReload;
@property(nonatomic, assign) NSTimeInterval lastShaderCheck;
@property(nonatomic, strong) NSDate *lastShaderReloadTime;
@property(nonatomic, assign) NSInteger preferredFPS;

// Global Parameters
@property(nonatomic, assign) float speed;
@property(nonatomic, assign) float intensity;
@property(nonatomic, assign) float gravity;

// Presets
@property(nonatomic, strong) NSString *currentPresetName;
@property(nonatomic, strong) NSDictionary *presets;

// Bloom
@property(nonatomic, assign) BOOL enableBloom;
@property(nonatomic, strong) id<MTLRenderPipelineState> thresholdPipeline;
@property(nonatomic, strong) id<MTLRenderPipelineState> blurHPipeline;
@property(nonatomic, strong) id<MTLRenderPipelineState> blurVPipeline;
@property(nonatomic, strong) id<MTLRenderPipelineState> combinePipeline;
@property(nonatomic, strong) id<MTLTexture> sceneTexture;
@property(nonatomic, strong) id<MTLTexture> bloomTextureA; // Threshold / Blur H
@property(nonatomic, strong) id<MTLTexture> bloomTextureB; // Blur V
@property(nonatomic, strong) id<MTLTexture> mainTexture;
@property(nonatomic, strong) id<MTLSamplerState> samplerState;

// Simulation State (Ping-Pong textures)
@property(nonatomic, strong) id<MTLTexture> simulationTextureA;
@property(nonatomic, strong) id<MTLTexture> simulationTextureB;
@property(nonatomic, assign) BOOL needsSimulation;

// Particle System
@property(nonatomic, strong, nullable) id<MTLComputePipelineState>
    particleComputePipeline;
@property(nonatomic, strong, nullable) id<MTLRenderPipelineState>
    particleRenderPipeline;
@property(nonatomic, strong, nullable) id<MTLBuffer> particleBuffer;
@property(nonatomic, assign) NSInteger numParticles;

@property(nonatomic, assign) BOOL isInitialized;
@property(nonatomic, assign) BOOL metalSetup;

- (void)loadShaders;
- (void)reloadShaders;
- (void)setupMetal;
- (void)createPipelineStateWithVertex:(NSString *)vertexFunc
                             fragment:(NSString *)fragmentFunc;

@end

NS_ASSUME_NONNULL_END
