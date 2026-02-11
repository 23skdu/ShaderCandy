//
//  ShaderCandyView.h
//  ShaderCandy
//
//  macOS Screen Saver Implementation
//

#import <ScreenSaver/ScreenSaver.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShaderCandyView : ScreenSaverView <MTKViewDelegate>

// Metal objects
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) MTKView *mtkView;

// Shader management
@property (nonatomic, strong) id<MTLLibrary> shaderLibrary;
@property (nonatomic, strong) NSString *currentShaderName;
@property (nonatomic, strong) NSArray<NSString *> *availableShaders;

// Timing
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, assign) NSInteger frameCount;

// Configuration
@property (nonatomic, assign) BOOL enableHotReload;
@property (nonatomic, assign) NSTimeInterval lastShaderCheck;

- (void)loadShaders;
- (void)reloadShaders;
- (void)setupMetal;
- (void)createPipelineStateWithVertex:(NSString *)vertexFunc 
                            fragment:(NSString *)fragmentFunc;

@end

NS_ASSUME_NONNULL_END
