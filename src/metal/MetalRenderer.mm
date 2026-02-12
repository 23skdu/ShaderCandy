//
//  MetalRenderer.mm
//  ShaderCandy
//
//  Unified Metal Renderer Implementation
//

#import "MetalRenderer.h"
#import <MetalKit/MetalKit.h>
#import <mach/mach.h>
#import <mach/vm_statistics.h>

#pragma mark - Error Implementation

@implementation MetalRendererError

+ (instancetype)errorWithCode:(MetalRendererErrorCode)code message:(NSString *)message {
    MetalRendererError *error = [[MetalRendererError alloc] init];
    error->_code = code;
    error->_message = [message copy];
    error->_timestamp = [NSDate date];
    return error;
}

+ (instancetype)shaderErrorWithMessage:(NSString *)message
                          compilerError:(NSString *)compilerError
                            shaderName:(NSString *)shaderName
                            lineNumber:(NSInteger)lineNumber {
    MetalRendererError *error = [[MetalRendererError alloc] init];
    error->_code = MetalRendererErrorCodeShaderCompilationFailed;
    error->_message = [message copy];
    error->_compilerError = [compilerError copy];
    error->_shaderName = [shaderName copy];
    error->_lineNumber = lineNumber;
    error->_timestamp = [NSDate date];
    return error;
}

@end

#pragma mark - Device Info Implementation

@implementation MetalDeviceInfo

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _name = device.name ?: @"Unknown";
        _isLowPower = device.isLowPower;
        _isHeadless = device.isHeadless;
        _recommendedMaxWorkingSetSize = device.recommendedMaxWorkingSetSize;

        // Detect GPU family
        if ([device supportsFamily:MTLGPUFamilyApple3]) {
            _family = MetalGPUFamilyApple3;
            _supportsTileShaders = YES;
            _supportsSimdGroups = YES;
            _supportsMeshShaders = YES;
        } else if ([device supportsFamily:MTLGPUFamilyApple2]) {
            _family = MetalGPUFamilyApple2;
            _supportsTileShaders = YES;
            _supportsSimdGroups = YES;
            _supportsMeshShaders = NO;
        } else if ([device supportsFamily:MTLGPUFamilyApple1]) {
            _family = MetalGPUFamilyApple1;
            _supportsTileShaders = YES;
            _supportsSimdGroups = YES;
            _supportsMeshShaders = NO;
        } else if ([device supportsFamily:MTLGPUFamilyMac2]) {
            _family = MetalGPUFamilyMac2;
            _supportsTileShaders = NO;
            _supportsSimdGroups = YES;
            _supportsMeshShaders = NO;
        } else if ([device supportsFamily:MTLGPUFamilyMac1]) {
            _family = MetalGPUFamilyMac1;
            _supportsTileShaders = NO;
            _supportsSimdGroups = YES;
            _supportsMeshShaders = NO;
        } else {
            _family = MetalGPUFamilyUnknown;
            _supportsTileShaders = NO;
            _supportsSimdGroups = YES;
            _supportsMeshShaders = NO;
        }

        // Use a reasonable default for thread group size
        // Actual value depends on compute pipeline, but 512 is safe for most GPUs
        _maxThreadsPerThreadgroup = 512;
    }
    return self;
}

@end

#pragma mark - Performance Metrics Implementation

@implementation MetalPerformanceMetrics

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentFPS = 0;
        _averageFPS = 0;
        _minFPS = 0;
        _maxFPS = 0;
        _frameTimeMs = 0;
        _gpuTimeMs = 0;
        _cpuTimeMs = 0;
        _droppedFrames = 0;
        _memoryUsageBytes = 0;
    }
    return self;
}

@end

#pragma mark - Pipeline State Implementation

@implementation MetalPipelineState

- (instancetype)initWithShaderName:(NSString *)shaderName {
    self = [super init];
    if (self) {
        _shaderName = [shaderName copy];
        _createdAt = [NSDate date];
    }
    return self;
}

@end

#pragma mark - Render Resources Implementation

@implementation MetalRenderResources

- (instancetype)init {
    self = [super init];
    if (self) {
        _viewportSize = CGSizeMake(1920, 1080);
        _simulationTextureSize = 512;
    }
    return self;
}

@end

#pragma mark - Bloom Configuration Implementation

@implementation MetalBloomConfig

+ (instancetype)defaultConfig {
    MetalBloomConfig *config = [[MetalBloomConfig alloc] init];
    config.enabled = YES;
    config.quality = MetalBloomQualityMedium;
    config.intensity = 0.8f;
    config.threshold = 0.8f;
    config.blurRadius = 8;
    return config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = YES;
        _quality = MetalBloomQualityMedium;
        _intensity = 0.8f;
        _threshold = 0.8f;
        _blurRadius = 8;
    }
    return self;
}

@end

#pragma mark - Particle Configuration Implementation

@implementation MetalParticleConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _count = 10000;
        _enabled = YES;
        _gravity = 1.0f;
        _speed = 1.0f;
    }
    return self;
}

@end

#pragma mark - Metal Renderer Private Interface

@interface MetalRenderer ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, MetalPipelineState *> *pipelineCache;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id<MTLLibrary>> *libraryCache;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *shaderModificationDates;
@property(nonatomic, strong) dispatch_queue_t shaderQueue;
@property(nonatomic, strong) dispatch_source_t fileWatcherSource;
@property(nonatomic, assign) NSUInteger inFlightBufferIndex;
@property(nonatomic, strong) dispatch_semaphore_t inFlightSemaphore;
@property(nonatomic, strong) NSDate *frameStartTime;
@property(nonatomic, strong) NSDate *shaderDirectoryPath;
@property(nonatomic, strong) NSDate *lastShaderCheckTime;
@property(nonatomic, assign) NSUInteger frameCount;
@property(nonatomic, assign) BOOL isDeviceLost;
@property(nonatomic, strong) NSMutableArray<MetalRendererError *> *errorLog;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *frameTimeHistory;
@property(nonatomic, assign) NSUInteger gpuTimestampStart;
@property(nonatomic, assign) NSUInteger gpuTimestampEnd;

@end

#pragma mark - Private Readwrite Extensions

@interface MetalRenderer ()

@property(nonatomic, strong, readwrite, nullable) MetalPipelineState *currentPipeline;
@property(nonatomic, strong, readwrite, nullable) NSString *activeShaderName;

@end

#pragma mark - Metal Renderer Implementation

@implementation MetalRenderer

#pragma mark - Initialization

+ (nullable instancetype)rendererWithDevice:(nullable id<MTLDevice>)device
                                      error:(NSError **)error {
    MetalRenderer *renderer = [[MetalRenderer alloc] init];
    if ([renderer initializeWithDevice:device error:error]) {
        return renderer;
    }
    return nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pipelineCache = [NSMutableDictionary dictionary];
        _libraryCache = [NSMutableDictionary dictionary];
        _shaderModificationDates = [NSMutableDictionary dictionary];
        _shaderQueue = dispatch_queue_create("com.shadercandy.shaders", DISPATCH_QUEUE_SERIAL);
        _bloomConfig = [MetalBloomConfig defaultConfig];
        _particleConfig = [[MetalParticleConfig alloc] init];
        _resources = [[MetalRenderResources alloc] init];
        _metrics = [[MetalPerformanceMetrics alloc] init];
        _errorLog = [NSMutableArray array];
        _frameTimeHistory = [NSMutableArray array];
        _inFlightSemaphore = dispatch_semaphore_create(3);
        _developmentMode = NO;
        _hotReloadEnabled = NO;
        _preferredFPS = 60.0f;
        _inFlightBufferIndex = 0;
        _frameCount = 0;
        _isDeviceLost = NO;
    }
    return self;
}

- (BOOL)initializeWithDevice:(nullable id<MTLDevice>)device
                       error:(NSError **)error {
    // Get device
    if (device) {
        _device = device;
    } else {
        _device = MTLCreateSystemDefaultDevice();
    }

    if (!_device) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalRenderer"
                                         code:MetalRendererErrorCodeDeviceCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create Metal device"}];
        }
        return NO;
    }

    _deviceInfo = [[MetalDeviceInfo alloc] initWithDevice:_device];

    // Create command queue
    _commandQueue = [_device newCommandQueue];
    if (!_commandQueue) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalRenderer"
                                         code:MetalRendererErrorCodeCommandQueueFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create Metal command queue"}];
        }
        return NO;
    }

    // Setup resources
    if (![self createVertexBuffers]) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalRenderer"
                                         code:MetalRendererErrorCodeTextureCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create vertex buffers"}];
        }
        return NO;
    }

    // Setup file watcher
    [self setupFileWatcher];

    // Register for device loss notifications
    [self registerForDeviceLoss];

    NSLog(@"MetalRenderer: Initialized with device %@ (Family: %ld)",
          _deviceInfo.name, (long)_deviceInfo.family);

    return YES;
}

- (void)shutdown {
    // Cancel file watcher
    if (_fileWatcherSource) {
        dispatch_source_cancel(_fileWatcherSource);
        _fileWatcherSource = nil;
    }

    // Clear caches
    [_pipelineCache removeAllObjects];
    [_libraryCache removeAllObjects];
    [_shaderModificationDates removeAllObjects];

    // Release Metal resources
    _resources = nil;
    _currentPipeline = nil;

    _device = nil;
    _commandQueue = nil;

    NSLog(@"MetalRenderer: Shutdown complete");
}

#pragma mark - Device Management

- (void)registerForDeviceLoss {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDeviceLossNotification:)
                                                 name:MTLDeviceWasRemovedNotification
                                               object:_device];
}

- (void)handleDeviceLossNotification:(NSNotification *)notification {
    NSLog(@"MetalRenderer: Device loss detected!");
    _isDeviceLost = YES;

    MetalRendererError *error = [MetalRendererError errorWithCode:MetalRendererErrorCodeDeviceLost
                                                          message:@"Metal device was removed"];
    [_errorLog addObject:error];

    if ([_delegate respondsToSelector:@selector(metalRenderer:didEncounterError:)]) {
        [_delegate metalRenderer:self didEncounterError:error];
    }
}

- (void)handleDeviceLoss {
    if (!_isDeviceLost) return;

    NSLog(@"MetalRenderer: Attempting to recover from device loss...");

    // Try to get a new device
    id<MTLDevice> newDevice = MTLCreateSystemDefaultDevice();
    if (newDevice) {
        NSError *error = nil;
        if ([self recoverWithDevice:newDevice error:&error]) {
            NSLog(@"MetalRenderer: Successfully recovered from device loss");
            _isDeviceLost = NO;
        } else {
            NSLog(@"MetalRenderer: Failed to recover from device loss: %@", error);
        }
    }
}

- (BOOL)recoverWithDevice:(id<MTLDevice>)device error:(NSError **)error {
    // Shutdown existing resources
    [_pipelineCache removeAllObjects];
    [_libraryCache removeAllObjects];

    _device = device;
    _deviceInfo = [[MetalDeviceInfo alloc] initWithDevice:_device];

    _commandQueue = [_device newCommandQueue];
    if (!_commandQueue) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalRenderer"
                                         code:MetalRendererErrorCodeCommandQueueFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create command queue during recovery"}];
        }
        return NO;
    }

    // Recreate resources
    if (![self createVertexBuffers]) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalRenderer"
                                         code:MetalRendererErrorCodeTextureCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to recreate buffers during recovery"}];
        }
        return NO;
    }

    // Recreate textures with new device
    [self createTexturesForSize:_resources.viewportSize];

    // Reload current shader
    if (_activeShaderName) {
        [self loadShaderWithName:_activeShaderName error:nil];
    }

    return YES;
}

#pragma mark - Buffer Creation

- (BOOL)createVertexBuffers {
    // Fullscreen quad vertices
    static const float vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f,  // Bottom-Left
         1.0f, -1.0f, 1.0f, 0.0f,  // Bottom-Right
        -1.0f,  1.0f, 0.0f, 1.0f,  // Top-Left
         1.0f,  1.0f, 1.0f, 1.0f   // Top-Right
    };

    static const uint16_t indices[] = {
        0, 1, 2,  // First Triangle
        2, 1, 3   // Second Triangle
    };

    _resources.vertexBuffer = [_device newBufferWithBytes:vertices
                                                  length:sizeof(vertices)
                                                 options:MTLResourceStorageModeShared];
    if (!_resources.vertexBuffer) return NO;

    _resources.indexBuffer = [_device newBufferWithBytes:indices
                                                 length:sizeof(indices)
                                                options:MTLResourceStorageModeShared];
    if (!_resources.indexBuffer) return NO;

    // Triple-buffered uniform buffer
    _resources.uniformBuffer = [_device newBufferWithLength:sizeof(Uniforms) * 3
                                                     options:MTLResourceStorageModeShared];
    if (!_resources.uniformBuffer) return NO;

    return YES;
}

#pragma mark - Texture Management

- (void)createTexturesForSize:(CGSize)size {
    if (size.width <= 0 || size.height <= 0) {
        size = CGSizeMake(1920, 1080);
    }

    _resources.viewportSize = size;

    MTLTextureDescriptor *texDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:(NSUInteger)size.width
                                    height:(NSUInteger)size.height
                                 mipmapped:NO];
    texDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

    _resources.sceneTexture = [_device newTextureWithDescriptor:texDesc];

    // Simulation textures
    NSInteger simSize = _resources.simulationTextureSize;
    MTLTextureDescriptor *simDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                     width:(NSUInteger)simSize
                                    height:(NSUInteger)simSize
                                 mipmapped:NO];
    simDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

    _resources.simulationTextureA = [_device newTextureWithDescriptor:simDesc];
    _resources.simulationTextureB = [_device newTextureWithDescriptor:simDesc];

    // Bloom textures (half resolution)
    texDesc.width = (NSUInteger)size.width / 2;
    texDesc.height = (NSUInteger)size.height / 2;

    _resources.bloomTextureA = [_device newTextureWithDescriptor:texDesc];
    _resources.bloomTextureB = [_device newTextureWithDescriptor:texDesc];

    // Sampler
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    _resources.samplerState = [_device newSamplerStateWithDescriptor:samplerDesc];

    NSLog(@"MetalRenderer: Created textures for size %.0f x %.0f", size.width, size.height);
}

- (void)setViewportSize:(CGSize)size {
    [self createTexturesForSize:size];

    // Recreate pipelines with new viewport dimensions
    if (_activeShaderName) {
        NSError *error = nil;
        [self loadShaderWithName:_activeShaderName error:&error];
    }
}

#pragma mark - Shader Loading

- (BOOL)loadShaderWithName:(NSString *)name error:(NSError **)error {
    dispatch_sync(_shaderQueue, ^{
        // Check for shader file
        NSString *path = [self pathForShader:name];
        if (!path) {
            if (error) {
                *error = [NSError errorWithDomain:@"MetalRenderer"
                                             code:MetalRendererErrorCodeShaderCompilationFailed
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Shader '%@' not found", name]}];
            }
            return;
        }

        // Check modification date
        NSDate *modDate = [self modificationDateForPath:path];
        NSDate *lastMod = self.shaderModificationDates[name];
        if (lastMod && [modDate isEqualToDate:lastMod] && self.pipelineCache[name]) {
            return; // Already loaded and unchanged
        }

        self.shaderModificationDates[name] = modDate;

        // Compile shader
        NSError *compileError = nil;
        NSString *source = [NSString stringWithContentsOfFile:path
                                                    encoding:NSUTF8StringEncoding
                                                       error:&compileError];
        if (!source) {
            if (error) {
                *error = compileError;
            }
            return;
        }

        // Create library with full source
        NSString *fullSource = [self prepareShaderSource:source forShader:name];
        id<MTLLibrary> library = [self.device newLibraryWithSource:fullSource
                                                           options:nil
                                                             error:&compileError];
        if (compileError) {
            [self handleShaderCompileError:compileError forShader:name source:fullSource];
            if (error) {
                *error = compileError;
            }
            return;
        }

        self.libraryCache[name] = library;

        // Create pipeline
        NSError *pipelineError = nil;
        MetalPipelineState *pipeline = [self createPipelineStateWithLibrary:library
                                                                   shaderName:name
                                                                       error:&pipelineError];
        if (pipelineError) {
            if (error) {
                *error = pipelineError;
            }
            return;
        }

        self.pipelineCache[name] = pipeline;
        self.currentPipeline = pipeline;
        self.activeShaderName = name;

        NSLog(@"MetalRenderer: Loaded shader '%@'", name);

        if ([self.delegate respondsToSelector:@selector(metalRenderer:didReloadShadersWithName:)]) {
            [self.delegate metalRenderer:self didReloadShadersWithName:name];
        }
    });

    return _pipelineCache[name] != nil;
}

- (NSString *)pathForShader:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:name ofType:@"metal" inDirectory:@"shaders"];
    return path;
}

- (NSDate *)modificationDateForPath:(NSString *)path {
    if (!path) return nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return [attrs fileModificationDate];
}

- (NSString *)prepareShaderSource:(NSString *)source forShader:(NSString *)shaderName {
    NSMutableString *fullSource = [NSMutableString string];

    // Prepend Metal standard library
    [fullSource appendString:@"#include <metal_stdlib>\nusing namespace metal;\n\n"];

    // Load and prepend interop header
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *interopPath = [bundle pathForResource:@"ShaderInterop" ofType:@"h" inDirectory:@"shaders"];
    if (!interopPath) {
        interopPath = [[bundle bundlePath] stringByDeletingLastPathComponent];
        interopPath = [interopPath stringByAppendingPathComponent:@"src/core/ShaderInterop.h"];
    }

    if (interopPath) {
        NSString *interopHeader = [NSString stringWithContentsOfFile:interopPath
                                                           encoding:NSUTF8StringEncoding
                                                              error:nil];
        if (interopHeader) {
            [fullSource appendString:interopHeader];
            [fullSource appendString:@"\n\n"];
        }
    }

    // Load and prepend utils
    NSString *utilsPath = [bundle pathForResource:@"utils" ofType:@"metal" inDirectory:@"shaders"];
    if (!utilsPath) {
        utilsPath = [[bundle bundlePath] stringByDeletingLastPathComponent];
        utilsPath = [utilsPath stringByAppendingPathComponent:@"shaders/base/utils.metal"];
    }

    if (utilsPath) {
        NSString *utilsSource = [NSString stringWithContentsOfFile:utilsPath
                                                         encoding:NSUTF8StringEncoding
                                                            error:nil];
        if (utilsSource) {
            // Strip metal_stdlib include from utils
            NSMutableString *cleanedUtils = [utilsSource mutableCopy];
            [cleanedUtils replaceOccurrencesOfString:@"#include <metal_stdlib>\n"
                                         withString:@""
                                            options:0
                                              range:NSMakeRange(0, cleanedUtils.length)];
            [cleanedUtils replaceOccurrencesOfString:@"using namespace metal;\n"
                                         withString:@""
                                            options:0
                                              range:NSMakeRange(0, cleanedUtils.length)];
            [fullSource appendString:cleanedUtils];
            [fullSource appendString:@"\n\n"];
        }
    }

    // Add vertex shader wrapper
    [fullSource appendString:
        @"vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n"
        @"    VertexOut out;\n"
        @"    out.position = float4(in.position, 0.0, 1.0);\n"
        @"    out.texCoord = in.texCoord;\n"
        @"    return out;\n"
        @"}\n\n"];

    // Add the main shader source
    [fullSource appendString:source];

    return fullSource;
}

- (void)handleShaderCompileError:(NSError *)error forShader:(NSString *)name source:(NSString *)source {
    NSLog(@"ShaderCandy: Failed to compile shader '%@': %@", name, error);

    // Write failed shader to home directory for debugging
    [self writeFailedShaderToFile:source fileName:[NSString stringWithFormat:@"%@_failed.metal", name]];

    MetalRendererError *rendererError = [MetalRendererError
        shaderErrorWithMessage:[NSString stringWithFormat:@"Shader compilation failed: %@", error.localizedDescription]
                  compilerError:error.localizedDescription
                    shaderName:name
                    lineNumber:0];
    [_errorLog addObject:rendererError];

    if ([_delegate respondsToSelector:@selector(metalRenderer:didEncounterError:)]) {
        [_delegate metalRenderer:self didEncounterError:rendererError];
    }
}

- (void)writeFailedShaderToFile:(NSString *)source fileName:(NSString *)fileName {
    NSString *homePath = NSHomeDirectory();
    NSString *debugPath = [homePath stringByAppendingPathComponent:fileName];
    [source writeToFile:debugPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"Failed shader written to: %@", debugPath);
}

- (MetalPipelineState *)createPipelineStateWithLibrary:(id<MTLLibrary>)library
                                             shaderName:(NSString *)name
                                                 error:(NSError **)error {
    MetalPipelineState *state = [[MetalPipelineState alloc] initWithShaderName:name];

    NSError *pipelineError = nil;

    // Main render pipeline
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragment_main"];

    if (!vertexFunc || !fragmentFunc) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalRenderer"
                                         code:MetalRendererErrorCodePipelineCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Missing shader functions"}];
        }
        return nil;
    }

    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragmentFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    // Vertex descriptor
    MTLVertexDescriptor *vDesc = [MTLVertexDescriptor vertexDescriptor];
    vDesc.attributes[0].format = MTLVertexFormatFloat2;
    vDesc.attributes[0].offset = 0;
    vDesc.attributes[0].bufferIndex = 0;
    vDesc.attributes[1].format = MTLVertexFormatFloat2;
    vDesc.attributes[1].offset = 8;
    vDesc.attributes[1].bufferIndex = 0;
    vDesc.layouts[0].stride = 16;
    desc.vertexDescriptor = vDesc;

    state.renderPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&pipelineError];
    if (pipelineError) {
        if (error) *error = pipelineError;
        return nil;
    }

    // Check for simulation pipeline
    id<MTLFunction> simFunc = [library newFunctionWithName:@"fragment_sim"];
    if (simFunc) {
        desc.fragmentFunction = simFunc;
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
        state.simulationPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:nil];
    }

    // Check for particle pipelines
    id<MTLFunction> computeFunc = [library newFunctionWithName:@"compute_particles"];
    if (computeFunc) {
        state.computePipeline = [_device newComputePipelineStateWithFunction:computeFunc error:nil];

        id<MTLFunction> vPartFunc = [library newFunctionWithName:@"vertex_particles"];
        id<MTLFunction> fPartFunc = [library newFunctionWithName:@"fragment_particles"];

        if (vPartFunc && fPartFunc) {
            MTLRenderPipelineDescriptor *pDesc = [[MTLRenderPipelineDescriptor alloc] init];
            pDesc.vertexFunction = vPartFunc;
            pDesc.fragmentFunction = fPartFunc;
            pDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            pDesc.colorAttachments[0].blendingEnabled = YES;
            pDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
            pDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            state.particleRenderPipeline = [_device newRenderPipelineStateWithDescriptor:pDesc error:nil];
        }
    }

    return state;
}

- (nullable MetalPipelineState *)createPipelineForShader:(NSString *)name
                                               error:(NSError **)error {
    id<MTLLibrary> library = _libraryCache[name];
    if (!library) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalRenderer"
                                         code:MetalRendererErrorCodeShaderCompilationFailed
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Library not found for shader: %@", name]}];
        }
        return nil;
    }

    return [self createPipelineStateWithLibrary:library shaderName:name error:error];
}

#pragma mark - Shader Discovery

- (NSArray<NSString *> *)availableShaderNames {
    NSMutableArray *shaders = [NSMutableArray array];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *shadersPath = [[bundle resourcePath] stringByAppendingPathComponent:@"shaders"];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:[NSURL fileURLWithPath:shadersPath]
                                     includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   errorHandler:nil];

    for (NSURL *fileURL in enumerator) {
        NSString *fileName;
        [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:nil];

        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if (![isDirectory boolValue] && [fileName hasSuffix:@".metal"]) {
            NSString *name = [fileName stringByDeletingPathExtension];
            // Skip utility shaders
            if (![name isEqualToString:@"common"] && ![name isEqualToString:@"utils"] &&
                ![name isEqualToString:@"ShaderInterop"] && ![name isEqualToString:@"bloom"] &&
                ![name isEqualToString:@"particles"]) {
                [shaders addObject:name];
            }
        }
    }

    [shaders sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return [shaders copy];
}

- (BOOL)setActiveShader:(NSString *)name error:(NSError **)error {
    return [self loadShaderWithName:name error:error];
}

- (BOOL)reloadCurrentShader:(NSError **)error {
    if (!_activeShaderName) return NO;
    [_pipelineCache removeObjectForKey:_activeShaderName];
    [_libraryCache removeObjectForKey:_activeShaderName];
    return [self loadShaderWithName:_activeShaderName error:error];
}

#pragma mark - Pipeline Pre-warming

- (void)prewarmPipelinesForShaders:(NSArray<NSString *> *)shaders {
    dispatch_async(_shaderQueue, ^{
        for (NSString *name in shaders) {
            if (!self.pipelineCache[name]) {
                [self loadShaderWithName:name error:nil];
            }
        }
    });
}

#pragma mark - File Watching

- (void)setupFileWatcher {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *shadersPath = [[bundle resourcePath] stringByAppendingPathComponent:@"shaders"];

    int fd = open([shadersPath UTF8String], O_RDONLY);
    if (fd < 0) return;

    _fileWatcherSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t)fd,
                                               DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE,
                                               _shaderQueue);

    dispatch_source_set_event_handler(_fileWatcherSource, ^{
        [self checkForShaderChanges];
    });

    dispatch_source_set_cancel_handler(_fileWatcherSource, ^{
        close(fd);
    });

    dispatch_resume(_fileWatcherSource);
}

- (void)checkForShaderChanges {
    if (!_hotReloadEnabled) return;

    NSDate *now = [NSDate date];
    if (_lastShaderCheckTime && [now timeIntervalSinceDate:_lastShaderCheckTime] < 1.0) {
        return; // Check at most once per second
    }
    _lastShaderCheckTime = now;

    for (NSString *name in _shaderModificationDates.allKeys) {
        NSString *path = [self pathForShader:name];
        NSDate *modDate = [self modificationDateForPath:path];
        NSDate *lastMod = _shaderModificationDates[name];

        if (modDate && lastMod && ![modDate isEqualToDate:lastMod]) {
            NSLog(@"MetalRenderer: Detected change in shader '%@', reloading...", name);
            [_pipelineCache removeObjectForKey:name];
            [_libraryCache removeObjectForKey:name];
            [self loadShaderWithName:name error:nil];
        }
    }
}

#pragma mark - Rendering

- (void)beginFrame {
    _frameStartTime = [NSDate date];
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)endFrame {
    NSTimeInterval frameTime = [[NSDate date] timeIntervalSinceDate:_frameStartTime] * 1000.0;
    [_frameTimeHistory addObject:@(frameTime)];

    // Keep only last 120 samples (2 seconds at 60fps)
    if (_frameTimeHistory.count > 120) {
        [_frameTimeHistory removeObjectAtIndex:0];
    }

    // Calculate metrics
    double avgFrameTime = 0;
    for (NSNumber *t in _frameTimeHistory) {
        avgFrameTime += t.doubleValue;
    }
    avgFrameTime /= _frameTimeHistory.count;

    _metrics.frameTimeMs = frameTime;
    _metrics.averageFPS = avgFrameTime > 0 ? 1000.0 / avgFrameTime : 0;
    _metrics.currentFPS = frameTime > 0 ? 1000.0 / frameTime : 0;
    _metrics.frameTimeMs = frameTime;

    // Dropped frames check
    if (frameTime > 33.3) { // Below 30fps
        _metrics.droppedFrames++;
    }

    _frameCount++;
    dispatch_semaphore_signal(_inFlightSemaphore);

    if ([_delegate respondsToSelector:@selector(metalRenderer:didUpdateMetrics:)]) {
        [_delegate metalRenderer:self didUpdateMetrics:_metrics];
    }
}

- (void)updateUniformsWithTime:(NSTimeInterval)time
                    mousePosition:(NSPoint)mousePos
                   mouseButtons:(NSInteger)buttons
                          speed:(float)speed
                      intensity:(float)intensity
                        gravity:(float)gravity
                         height:(CGFloat)height {
    NSUInteger bufferIndex = _frameCount % 3;
    uint8_t *bufferPtr = (uint8_t *)_resources.uniformBuffer.contents;
    Uniforms *uniforms = (Uniforms *)(bufferPtr + bufferIndex * sizeof(Uniforms));

    uniforms->time = (float)time;
    uniforms->speed = speed;
    uniforms->intensity = intensity;
    uniforms->gravity = gravity;
    uniforms->mouseButtons = (float)buttons;

    // Resolution
    uniforms->resolution = (vector_float2){
        (float)_resources.viewportSize.width,
        (float)_resources.viewportSize.height
    };

    // Mouse position
    uniforms->mouse = (vector_float2){
        (float)(mousePos.x / (_resources.viewportSize.width ?: 1)),
        (float)(mousePos.y / (_resources.viewportSize.height ?: 1))
    };

    // Date
    NSDateComponents *components = [[NSCalendar currentCalendar]
        components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                   NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
          fromDate:[NSDate date]];
    uniforms->date = (vector_float4){
        (float)components.year, (float)components.month, (float)components.day,
        (float)(components.hour * 3600 + components.minute * 60 + components.second)
    };

    uniforms->frame = (int32_t)_frameCount;
    uniforms->deltaTime = 1.0f / _preferredFPS;
    uniforms->alpha = 1.0f;
}

- (void)renderToDrawable:(id<CAMetalDrawable>)drawable
      renderPassDescriptor:(MTLRenderPassDescriptor *)descriptor {
    if (!_currentPipeline || !_commandQueue) return;

    [self beginFrame];

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    __block dispatch_semaphore_t semaphore = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(semaphore);
    }];

    // Get current buffer index
    NSUInteger bufferIndex = _frameCount % 3;
    uint8_t *bufferPtr = (uint8_t *)_resources.uniformBuffer.contents;
    Uniforms *uniforms = (Uniforms *)(bufferIndex * sizeof(Uniforms) + bufferPtr);

    // Render based on configuration
    if (_bloomConfig.enabled && _resources.sceneTexture) {
        [self renderWithBloomToDrawable:drawable
                         commandBuffer:commandBuffer
                          renderDescriptor:descriptor
                                 uniforms:uniforms
                            bufferIndex:bufferIndex];
    } else {
        [self renderSimpleToDrawable:drawable
                      commandBuffer:commandBuffer
                 renderDescriptor:descriptor
                        uniforms:uniforms
                    bufferIndex:bufferIndex];
    }

    // Particle pass
    if (_particleConfig.enabled && _currentPipeline.computePipeline) {
        [self renderParticlesWithCommandBuffer:commandBuffer
                                      uniforms:uniforms
                                  bufferIndex:bufferIndex];
    }

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];

    [self endFrame];
}

- (void)renderSimpleToDrawable:(id<CAMetalDrawable>)drawable
                commandBuffer:(id<MTLCommandBuffer>)commandBuffer
           renderDescriptor:(MTLRenderPassDescriptor *)descriptor
                  uniforms:(Uniforms *)uniforms
              bufferIndex:(NSUInteger)bufferIndex {
    descriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;

    id<MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [encoder setRenderPipelineState:_currentPipeline.renderPipeline];
    [encoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
    [encoder setFragmentBuffer:_resources.uniformBuffer
                       offset:bufferIndex * sizeof(Uniforms)
                      atIndex:0];
    [encoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];

    if (_resources.mainTexture) {
        [encoder setFragmentTexture:_resources.mainTexture atIndex:0];
    }
    if (_resources.samplerState) {
        [encoder setFragmentSamplerState:_resources.samplerState atIndex:0];
    }

    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:6
                         indexType:MTLIndexTypeUInt16
                       indexBuffer:_resources.indexBuffer
                 indexBufferOffset:0];
    [encoder endEncoding];
}

- (void)renderWithBloomToDrawable:(id<CAMetalDrawable>)drawable
                   commandBuffer:(id<MTLCommandBuffer>)commandBuffer
              renderDescriptor:(MTLRenderPassDescriptor *)finalDesc
                     uniforms:(Uniforms *)uniforms
                 bufferIndex:(NSUInteger)bufferIndex {
    // Scene pass to offscreen texture
    MTLRenderPassDescriptor *sceneDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    sceneDesc.colorAttachments[0].texture = _resources.sceneTexture;
    sceneDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    sceneDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    sceneDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

    id<MTLRenderCommandEncoder> sceneEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:sceneDesc];
    [sceneEncoder setRenderPipelineState:_currentPipeline.renderPipeline];
    [sceneEncoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
    [sceneEncoder setFragmentBuffer:_resources.uniformBuffer
                           offset:bufferIndex * sizeof(Uniforms)
                          atIndex:0];
    [sceneEncoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];

    if (_resources.mainTexture) {
        [sceneEncoder setFragmentTexture:_resources.mainTexture atIndex:0];
    }
    if (_resources.samplerState) {
        [sceneEncoder setFragmentSamplerState:_resources.samplerState atIndex:0];
    }

    [sceneEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                             indexCount:6
                              indexType:MTLIndexTypeUInt16
                            indexBuffer:_resources.indexBuffer
                      indexBufferOffset:0];
    [sceneEncoder endEncoding];

    // Threshold pass
    MTLRenderPassDescriptor *bloomDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    bloomDesc.colorAttachments[0].texture = _resources.bloomTextureA;
    bloomDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    bloomDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> threshEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:bloomDesc];
    [threshEncoder setRenderPipelineState:[self bloomPipeline:@"bloom_threshold"]];
    [threshEncoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
    [threshEncoder setFragmentTexture:_resources.sceneTexture atIndex:0];
    [threshEncoder setFragmentSamplerState:_resources.samplerState atIndex:0];
    [threshEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:6
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:_resources.indexBuffer
                        indexBufferOffset:0];
    [threshEncoder endEncoding];

    // Horizontal blur
    bloomDesc.colorAttachments[0].texture = _resources.bloomTextureB;
    id<MTLRenderCommandEncoder> blurHEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:bloomDesc];
    [blurHEncoder setRenderPipelineState:[self bloomPipeline:@"bloom_blur_h"]];
    [blurHEncoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
    [blurHEncoder setFragmentTexture:_resources.bloomTextureA atIndex:0];
    [blurHEncoder setFragmentSamplerState:_resources.samplerState atIndex:0];
    [blurHEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                              indexCount:6
                               indexType:MTLIndexTypeUInt16
                             indexBuffer:_resources.indexBuffer
                       indexBufferOffset:0];
    [blurHEncoder endEncoding];

    // Vertical blur
    bloomDesc.colorAttachments[0].texture = _resources.bloomTextureA;
    id<MTLRenderCommandEncoder> blurVEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:bloomDesc];
    [blurVEncoder setRenderPipelineState:[self bloomPipeline:@"bloom_blur_v"]];
    [blurVEncoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
    [blurVEncoder setFragmentTexture:_resources.bloomTextureB atIndex:0];
    [blurVEncoder setFragmentSamplerState:_resources.samplerState atIndex:0];
    [blurVEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                              indexCount:6
                               indexType:MTLIndexTypeUInt16
                             indexBuffer:_resources.indexBuffer
                       indexBufferOffset:0];
    [blurVEncoder endEncoding];

    // Combine pass
    id<MTLRenderCommandEncoder> finalEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:finalDesc];
    [finalEncoder setRenderPipelineState:[self bloomPipeline:@"bloom_combine"]];
    [finalEncoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
    [finalEncoder setFragmentTexture:_resources.sceneTexture atIndex:0];
    [finalEncoder setFragmentTexture:_resources.bloomTextureA atIndex:1];
    [finalEncoder setFragmentSamplerState:_resources.samplerState atIndex:0];
    [finalEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                              indexCount:6
                               indexType:MTLIndexTypeUInt16
                             indexBuffer:_resources.indexBuffer
                       indexBufferOffset:0];
    [finalEncoder endEncoding];
}

- (id<MTLRenderPipelineState>)bloomPipeline:(NSString *)functionName {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });

    id<MTLRenderPipelineState> cached = cache[functionName];
    if (cached) return cached;

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"bloom" ofType:@"metal" inDirectory:@"shaders"];
    if (!path) return nil;

    NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!source) return nil;

    NSString *fullSource = [self prepareShaderSource:source forShader:@"bloom"];
    NSError *error = nil;
    id<MTLLibrary> library = [_device newLibraryWithSource:fullSource options:nil error:&error];
    if (error || !library) return nil;

    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:functionName];
    if (!vertexFunc || !fragmentFunc) return nil;

    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragmentFunc;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    MTLVertexDescriptor *vDesc = [MTLVertexDescriptor vertexDescriptor];
    vDesc.attributes[0].format = MTLVertexFormatFloat2;
    vDesc.attributes[0].offset = 0;
    vDesc.attributes[0].bufferIndex = 0;
    vDesc.attributes[1].format = MTLVertexFormatFloat2;
    vDesc.attributes[1].offset = 8;
    vDesc.attributes[1].bufferIndex = 0;
    vDesc.layouts[0].stride = 16;
    desc.vertexDescriptor = vDesc;

    id<MTLRenderPipelineState> pipeline = [_device newRenderPipelineStateWithDescriptor:desc error:nil];
    if (pipeline) {
        cache[functionName] = pipeline;
    }
    return pipeline;
}

- (void)renderParticlesWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                uniforms:(Uniforms *)uniforms
                            bufferIndex:(NSUInteger)bufferIndex {
    if (!_currentPipeline.computePipeline) return;

    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder setComputePipelineState:_currentPipeline.computePipeline];
    [computeEncoder setBuffer:_resources.uniformBuffer
                       offset:bufferIndex * sizeof(Uniforms)
                      atIndex:0];

    MTLSize gridSize = MTLSizeMake(_particleConfig.count, 1, 1);
    NSUInteger threadGroupSize = _currentPipeline.computePipeline.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > (NSUInteger)_particleConfig.count) {
        threadGroupSize = _particleConfig.count;
    }
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);

    [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
    [computeEncoder endEncoding];
}

#pragma mark - Bloom Control

- (void)setBloomEnabled:(BOOL)enabled {
    _bloomConfig.enabled = enabled;
}

- (void)setBloomQuality:(MetalBloomQuality)quality {
    _bloomConfig.quality = quality;
}

- (void)setBloomIntensity:(float)intensity {
    _bloomConfig.intensity = intensity;
}

#pragma mark - Particle Control

- (void)setParticlesEnabled:(BOOL)enabled {
    _particleConfig.enabled = enabled;
}

- (void)setParticleCount:(NSInteger)count {
    _particleConfig.count = count;
}

- (void)setParticleGravity:(float)gravity {
    _particleConfig.gravity = gravity;
}

#pragma mark - Metrics

- (nullable MetalPerformanceMetrics *)getMetrics {
    return _metrics;
}

- (void)resetMetrics {
    [_frameTimeHistory removeAllObjects];
    _metrics.droppedFrames = 0;
    _frameCount = 0;
}

#pragma mark - Debug

- (void)captureGPUFrame {
#if DEBUG
    // Metal debugger capture is triggered via environment variable or Xcode
    // This is a placeholder for programmatic capture points
    NSLog(@"MetalRenderer: GPU frame capture triggered (use Xcode Metal Debugger)");
#endif
}

@end
