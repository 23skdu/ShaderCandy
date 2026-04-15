//
//  MetalRenderer.mm
//  ShaderCandy
//
//  Unified Metal Renderer Implementation
//

#import "MetalRenderer.h"
#include "../audio/AudioInput.h"
#import "../audio/SoundscapeGenerator.h"
#import "../neural/NeuralStyleEngine.h"
#import "HDRPipeline.h"
#import "MTLPerformanceReporter.h"
#import "MetalHeapManager.h"
#import "MetalResourcePool.h"
#import "MetalSharedState.h"
#import "ShaderCompiler.h"
#import <MetalKit/MetalKit.h>
#import <mach/mach.h>
#import <mach/vm_statistics.h>
#include <memory>
#import <objc/runtime.h>

// One-shot hook used by the macOS screenshot utility.
typedef void (^SCScreenshotEncodeHook)(id<MTLCommandBuffer> commandBuffer,
                                       id<MTLTexture> sourceTexture);

#pragma mark - Error Implementation

@implementation MetalRendererError

+ (instancetype)errorWithCode:(MetalRendererErrorCode)code
                      message:(NSString *)message {
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

    // Detect GPU family - optimized with branchless pattern
    // Check capabilities using bitwise flags to avoid branch misprediction
    BOOL supportsApple3 = [device supportsFamily:MTLGPUFamilyApple3];
    BOOL supportsApple2 = [device supportsFamily:MTLGPUFamilyApple2];
    BOOL supportsApple1 = [device supportsFamily:MTLGPUFamilyApple1];
    BOOL supportsMac2 = [device supportsFamily:MTLGPUFamilyMac2];
    BOOL supportsMac1 = [device supportsFamily:MTLGPUFamilyMac1];
    
    // Branchless family detection using cascading boolean logic
    _family = supportsApple3 ? MetalGPUFamilyApple3 :
              supportsApple2 ? MetalGPUFamilyApple2 :
              supportsApple1 ? MetalGPUFamilyApple1 :
              supportsMac2    ? MetalGPUFamilyMac2 :
              supportsMac1    ? MetalGPUFamilyMac1 :
                                MetalGPUFamilyUnknown;
    
    // Branchless capability flag computation using bitwise operations
    // Tile shaders: only available on Apple silicon (Apple1/2/3)
    _supportsTileShaders = (supportsApple1 || supportsApple2 || supportsApple3) ? YES : NO;
    
    // SIMD groups: available on all Apple silicon and modern Mac GPUs
    _supportsSimdGroups = (supportsApple1 || supportsApple2 || supportsApple3 || supportsMac2 || supportsMac1) ? YES : NO;
    
    // Mesh shaders: only available on Apple3+
    _supportsMeshShaders = supportsApple3 ? YES : NO;

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
  config.enabled = NO;
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

@property(nonatomic, strong)
    NSMutableDictionary<NSString *, MetalPipelineState *> *pipelineCache;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, id<MTLLibrary>> *libraryCache;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSDate *> *shaderModificationDates;
@property(nonatomic, strong) dispatch_queue_t shaderQueue;
@property(nonatomic, strong) dispatch_source_t fileWatcherSource;
@property(nonatomic, assign) NSUInteger inFlightBufferIndex;
@property(nonatomic, strong) dispatch_semaphore_t inFlightSemaphore;
@property(nonatomic, strong) NSDate *frameStartTime;
@property(nonatomic, strong) NSDate *shaderDirectoryPath;
@property(nonatomic, strong) NSDate *lastShaderCheckTime;
@property(nonatomic, assign) NSUInteger frameCount;
@property(nonatomic, assign) BOOL isDeviceLost;
@property(nonatomic, strong) NSCalendar *calendar;
@property(nonatomic, strong) NSDateComponents *dateComponents;
@property(nonatomic, copy) NSString *cachedInteropHeader;
@property(nonatomic, copy) NSString *cachedUtilsSource;

@property(nonatomic, strong) NSMutableArray<MetalRendererError *> *errorLog;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *frameTimeHistory;
@property(nonatomic, assign) NSUInteger gpuTimestampStart;
@property(nonatomic, assign) NSUInteger gpuTimestampEnd;

// Transition state
@property(nonatomic, assign, readwrite) BOOL isTransitioning;
@property(nonatomic, assign, readwrite) float transitionAlpha;
@property(nonatomic, strong, readwrite, nullable)
    MetalPipelineState *previousPipeline;
@property(nonatomic, assign) NSTimeInterval transitionDuration;
@property(nonatomic, strong, nullable) NSDate *transitionStartTime;
@property(nonatomic, strong, nullable) NSString *previousShaderName;
@property(nonatomic, strong, nullable) id<MTLRenderPipelineState> crossfadePipeline;

@end

#pragma mark - Private Readwrite Extensions

@interface MetalRenderer ()

@property(nonatomic, strong, readwrite, nullable)
    MetalPipelineState *currentPipeline;
@property(nonatomic, strong, readwrite, nullable) NSString *activeShaderName;
@property(nonatomic, strong, readwrite) MetalResourcePool *resourcePool;
@property(nonatomic, strong, readwrite)
    MTLPerformanceReporter *performanceReporter;
@property(nonatomic, strong) MetalHeapManager *heapManager;

@end

#pragma mark - Metal Renderer Implementation

@implementation MetalRenderer {
  std::unique_ptr<ShaderCandy::Audio::AudioInput> _audioInput;
}

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
    _shaderQueue =
        dispatch_queue_create("com.shadercandy.shaders", DISPATCH_QUEUE_SERIAL);
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
    _autoScalingEnabled = YES;
    _autoScaleFPSThreshold = 55.0f;
    _calendar = [NSCalendar currentCalendar];
    _dateComponents = [[NSDateComponents alloc] init];

    // Frame synchronization defaults
    _adaptiveSyncEnabled = YES;
    _framePacingEnabled = YES;
    _targetFrameTime = 1.0 / 60.0;

    // Dynamic resolution defaults
    _dynamicResolutionEnabled = NO;
    _resolutionScale = 1.0f;
    _maxTextureDimension = 8192.0f;

    // Memory management defaults (will be adjusted based on device)
    _maxMemoryBudgetBytes = 256 * 1024 * 1024; // 256MB default
    _currentMemoryUsageBytes = 0;
    _aggressiveMemoryPurge = NO;

    // Performance state
    _isThermalThrottling = NO;
    _thermalLevel = 0.0f;
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
      *error = [NSError
          errorWithDomain:@"MetalRenderer"
                     code:MetalRendererErrorCodeDeviceCreationFailed
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Failed to create Metal device"
                 }];
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
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Failed to create Metal command queue"
                               }];
    }
    return NO;
  }

  _resourcePool = [[MetalResourcePool alloc] initWithDevice:_device];
  _performanceReporter =
      [[MTLPerformanceReporter alloc] initWithDevice:_device];

  // Configure memory budget and texture limits based on device capabilities
  [self configureDeviceCapabilities];

  // Initialize heap manager with error handling
  _heapManager = [[MetalHeapManager alloc]
      initWithDevice:_device
                size:64 * 1024 * 1024]; // 64MB heap (more conservative)
  if (!_heapManager) {
    if (error) {
      *error =
          [NSError errorWithDomain:@"MetalRenderer"
                              code:MetalRendererErrorCodeResourceExhausted
                          userInfo:@{
                            NSLocalizedDescriptionKey :
                                @"Failed to create Metal heap manager - Metal "
                                @"may not be supported on this device"
                          }];
    }
    return NO;
  }

  // Setup resources
  if (![self createVertexBuffers]) {
    if (error) {
      *error =
          [NSError errorWithDomain:@"MetalRenderer"
                              code:MetalRendererErrorCodeTextureCreationFailed
                          userInfo:@{
                            NSLocalizedDescriptionKey :
                                @"Failed to create vertex buffers"
                          }];
    }
    return NO;
  }

  if (![self createParticleBuffers]) {
  #ifdef DEBUG
  NSLog(@"MetalRenderer: Warning - Failed to create particle buffers");
#endif
  }

  // Setup file watcher
  [self setupFileWatcher];

  // Register for device loss notifications
  [self registerForDeviceLoss];

  // Skip debug overlay for standalone app to avoid shader compilation issues
  // [self setupDebugOverlay];

  // Initialize HDR Pipeline - but keep SDR path as default to avoid blank screen
  // when sceneTexture is not yet allocated. HDR can be enabled by user preference.
  [[HDRPipeline sharedPipeline] initializeWithDevice:_device error:nil];
  _hdrEnabled = NO; // Start with SDR path; set via detectHDRDisplay only if user enables HDR
  _toneMapping = ToneMappingOperatorACES;
  _maxBrightness = 1000.0f;

  // Initialize Neural Engine
  [[NeuralStyleEngine sharedEngine] initializeWithDevice:_device error:nil];
  _neuralStyleEnabled = NO;
  _styleStrength = 0.5f;

#ifdef DEBUG
  NSLog(@"MetalRenderer: Initialized with device %@ (Family: %ld)",
        _deviceInfo.name, (long)_deviceInfo.family);
#endif

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

#ifdef DEBUG
  NSLog(@"MetalRenderer: Shutdown complete");
#endif
}

#pragma mark - Device Capabilities

- (void)configureDeviceCapabilities {
  if (!_device)
    return;

  NSUInteger recommendedWorkingSet = _device.recommendedMaxWorkingSetSize;

  // Set memory budget to 50% of recommended working set to leave headroom
  _maxMemoryBudgetBytes = recommendedWorkingSet / 2;

  // Adjust texture limits based on device - branchless approach
  BOOL supportsApple3 = [_device supportsFamily:MTLGPUFamilyApple3];
  BOOL supportsApple2 = [_device supportsFamily:MTLGPUFamilyApple2];
  BOOL supportsMac2 = [_device supportsFamily:MTLGPUFamilyMac2];
  
  // Branchless texture dimension selection
  _maxTextureDimension = supportsApple3 ? 16384.0f :
                         supportsApple2 ? 8192.0f :
                         supportsMac2    ? 16384.0f :
                                          8192.0f;

  // Enable dynamic resolution for high-res displays by default
  NSScreen *mainScreen = [NSScreen mainScreen];
  if (mainScreen) {
    CGSize screenSize = mainScreen.frame.size;
    if (screenSize.width >= 3840 || screenSize.height >= 2160) {
      _dynamicResolutionEnabled = YES;
      _resolutionScale = 0.75f; // Start at 75% for 4K+
#ifdef DEBUG
      NSLog(
          @"MetalRenderer: 4K+ display detected, enabling dynamic resolution");
#endif
    }
  }

  // Configure resource pool with adjusted limits
  _resourcePool.maxMemoryUsageBytes = _maxMemoryBudgetBytes;

#ifdef DEBUG
  NSLog(@"MetalRenderer: Configured for device %@ - Memory budget: %luMB, Max "
        @"texture: %.0f",
        _device.name, (unsigned long)(_maxMemoryBudgetBytes / 1024 / 1024),
        _maxTextureDimension);
#endif
}

- (void)updateThermalState {
#if TARGET_OS_MAC
  NSProcessInfoThermalState thermalState =
      [[NSProcessInfo processInfo] thermalState];
  switch (thermalState) {
  case NSProcessInfoThermalStateNominal:
    _thermalLevel = 0.0f;
    _isThermalThrottling = NO;
    break;
  case NSProcessInfoThermalStateFair:
    _thermalLevel = 0.33f;
    _isThermalThrottling = NO;
    break;
  case NSProcessInfoThermalStateSerious:
    _thermalLevel = 0.66f;
    _isThermalThrottling = YES;
    break;
  case NSProcessInfoThermalStateCritical:
    _thermalLevel = 1.0f;
    _isThermalThrottling = YES;
    break;
  }

  // Apply thermal throttling - reduce quality and target FPS
  if (_isThermalThrottling) {
    if (_preferredFPS > 30.0f) {
      _preferredFPS = 30.0f;
      _targetFrameTime = 1.0 / 30.0;
#ifdef DEBUG
      NSLog(@"MetalRenderer: Thermal throttling active - reducing to 30fps");
#endif
    }
    if (_bloomConfig.enabled) {
      _bloomConfig.enabled = NO;
#ifdef DEBUG
      NSLog(@"MetalRenderer: Thermal throttling - disabling bloom");
#endif
    }
  }
#endif
}

#pragma mark - Device Management

- (void)registerForDeviceLoss {
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(handleDeviceLossNotification:)
             name:MTLDeviceWasRemovedNotification
            object:_device];
#ifdef DEBUG
  NSLog(@"Device loss notification registered");
#endif
}

- (void)handleDeviceLossNotification:(NSNotification *)notification {
#ifdef DEBUG
  NSLog(@"MetalRenderer: Device loss detected!");
#endif
  _isDeviceLost = YES;

  MetalRendererError *error =
      [MetalRendererError errorWithCode:MetalRendererErrorCodeDeviceLost
                                message:@"Metal device was removed"];
  [_errorLog addObject:error];

  if ([_delegate respondsToSelector:@selector(metalRenderer:
                                          didEncounterError:)]) {
    [_delegate metalRenderer:self didEncounterError:error];
  }
}

- (void)handleDeviceLoss {
  if (!_isDeviceLost)
    return;

#ifdef DEBUG
  NSLog(@"MetalRenderer: Attempting to recover from device loss...");
#endif

  // Try to get a new device
  id<MTLDevice> newDevice = MTLCreateSystemDefaultDevice();
  if (newDevice) {
    NSError *error = nil;
    if ([self recoverWithDevice:newDevice error:&error]) {
#ifdef DEBUG
      NSLog(@"MetalRenderer: Successfully recovered from device loss");
#endif
      _isDeviceLost = NO;
    } else {
#ifdef DEBUG
      NSLog(@"MetalRenderer: Failed to recover from device loss: %@", error);
#endif
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
      *error = [NSError
          errorWithDomain:@"MetalRenderer"
                     code:MetalRendererErrorCodeCommandQueueFailed
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       @"Failed to create command queue during recovery"
                 }];
    }
    return NO;
  }

  // Recreate resources
  if (![self createVertexBuffers]) {
    if (error) {
      *error =
          [NSError errorWithDomain:@"MetalRenderer"
                              code:MetalRendererErrorCodeTextureCreationFailed
                          userInfo:@{
                            NSLocalizedDescriptionKey :
                                @"Failed to recreate buffers during recovery"
                          }];
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
      -1.0f, -1.0f, 0.0f, 0.0f, // Bottom-Left
      1.0f,  -1.0f, 1.0f, 0.0f, // Bottom-Right
      -1.0f, 1.0f,  0.0f, 1.0f, // Top-Left
      1.0f,  1.0f,  1.0f, 1.0f  // Top-Right
  };

  static const uint16_t indices[] = {
      0, 1, 2, // First Triangle
      2, 1, 3  // Second Triangle
  };

  _resources.vertexBuffer =
      [_device newBufferWithBytes:vertices
                           length:sizeof(vertices)
                          options:MTLResourceStorageModeShared];
  if (!_resources.vertexBuffer)
    return NO;

  _resources.indexBuffer =
      [_device newBufferWithBytes:indices
                           length:sizeof(indices)
                          options:MTLResourceStorageModeShared];
  if (!_resources.indexBuffer)
    return NO;

  // Triple-buffered uniform buffer
  _resources.uniformBuffer =
      [_device newBufferWithLength:sizeof(Uniforms) * 3
                           options:MTLResourceStorageModeShared];
  if (!_resources.uniformBuffer)
    return NO;

  return YES;
}

- (BOOL)createParticleBuffers {
  // Try different buffer sizes from smallest to larger
  NSArray<NSNumber *> *bufferSizes = @[
    @(1 * sizeof(Particle)),   // 1 particle (48 bytes)
    @(1024 * sizeof(Particle)) // 1024 particles
  ];

  NSUInteger particleBufferSize = [bufferSizes.lastObject unsignedLongValue];

  if (_heapManager) {
#ifdef DEBUG
    NSLog(@"MetalRenderer: Attempting to create particle buffers from heap "
          @"with size %lu",
          (unsigned long)particleBufferSize);
#endif

    _resources.particleBufferA =
        [_heapManager newBufferWithLength:particleBufferSize
                                  options:MTLResourceStorageModeShared];
    _resources.particleBufferB =
        [_heapManager newBufferWithLength:particleBufferSize
                                  options:MTLResourceStorageModeShared];

    if (_resources.particleBufferA && _resources.particleBufferB) {
#ifdef DEBUG
      NSLog(@"MetalRenderer: Successfully created particle buffers from heap");
#endif
      return YES;
    }
#ifdef DEBUG
    NSLog(@"MetalRenderer: Heap allocation failed, falling back to device "
          @"allocation");
#endif
  } else {
#ifdef DEBUG
    NSLog(@"MetalRenderer: Heap manager unavailable, falling back to device "
          @"allocation");
#endif
  }

  // Fallback to direct device allocation if heap fails or is unavailable
  _resources.particleBufferA =
      [_device newBufferWithLength:particleBufferSize
                           options:MTLResourceStorageModeShared];
  _resources.particleBufferB =
      [_device newBufferWithLength:particleBufferSize
                           options:MTLResourceStorageModeShared];

  if (_resources.particleBufferA && _resources.particleBufferB) {
#ifdef DEBUG
    NSLog(@"MetalRenderer: Successfully created particle buffers via direct "
          @"device allocation");
#endif
    return YES;
  }

#ifdef DEBUG
  NSLog(@"MetalRenderer: CRITICAL - Failed to create particle buffers via any "
        @"method");
#endif
  return NO;
}

#pragma mark - Texture Management

- (void)createTexturesForSize:(CGSize)size {
  if (size.width <= 0 || size.height <= 0) {
    size = CGSizeMake(1920, 1080);
  }

  // Apply dynamic resolution scaling for ultra-high resolution displays
  CGSize renderSize = size;
  if (_dynamicResolutionEnabled && _resolutionScale < 1.0f) {
    renderSize.width = size.width * _resolutionScale;
    renderSize.height = size.height * _resolutionScale;

    // Clamp to max texture dimension
    if (renderSize.width > _maxTextureDimension) {
      renderSize.width = _maxTextureDimension;
      _resolutionScale = _maxTextureDimension / size.width;
      renderSize.height = size.height * _resolutionScale;
    }
    if (renderSize.height > _maxTextureDimension) {
      renderSize.height = _maxTextureDimension;
      _resolutionScale = _maxTextureDimension / size.height;
      renderSize.width = size.width * _resolutionScale;
    }
  }

  _resources.viewportSize = size;

  MTLTextureDescriptor *texDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                   width:(NSUInteger)renderSize.width
                                  height:(NSUInteger)renderSize.height
                               mipmapped:NO];
  texDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

  if (_resources.sceneTexture)
    [_resourcePool returnTexture:_resources.sceneTexture];
  _resources.sceneTexture = [_resourcePool getTextureWithDescriptor:texDesc];

  // Transition texture - same size as scene texture, used for crossfade render
  if (_resources.transitionTexture)
    [_resourcePool returnTexture:_resources.transitionTexture];
  _resources.transitionTexture = [_resourcePool getTextureWithDescriptor:texDesc];

  // Simulation textures - always at fixed resolution for consistency
  NSInteger simSize = _resources.simulationTextureSize;
  MTLTextureDescriptor *simDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                   width:(NSUInteger)simSize
                                  height:(NSUInteger)simSize
                               mipmapped:NO];
  simDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

  if (_resources.simulationTextureA)
    [_resourcePool returnTexture:_resources.simulationTextureA];
  if (_resources.simulationTextureB)
    [_resourcePool returnTexture:_resources.simulationTextureB];
  _resources.simulationTextureA =
      [_resourcePool getTextureWithDescriptor:simDesc];
  _resources.simulationTextureB =
      [_resourcePool getTextureWithDescriptor:simDesc];

  // Bloom textures - use quarter resolution for performance at high-res
  CGFloat bloomScale = _dynamicResolutionEnabled ? 0.25f : 0.5f;
  texDesc.width = (NSUInteger)(renderSize.width * bloomScale);
  texDesc.height = (NSUInteger)(renderSize.height * bloomScale);

  if (_resources.bloomTextureA)
    [_resourcePool returnTexture:_resources.bloomTextureA];
  if (_resources.bloomTextureB)
    [_resourcePool returnTexture:_resources.bloomTextureB];
  _resources.bloomTextureA = [_resourcePool getTextureWithDescriptor:texDesc];
  _resources.bloomTextureB = [_resourcePool getTextureWithDescriptor:texDesc];

  // Sampler
  MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
  samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
  samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
  samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
  samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
  _resources.samplerState = [_device newSamplerStateWithDescriptor:samplerDesc];

#ifdef DEBUG
  NSLog(@"MetalRenderer: Created textures for viewport %.0f x %.0f -> render "
        @"%.0f x %.0f (scale: %.2f)",
        size.width, size.height, renderSize.width, renderSize.height,
        _resolutionScale);
#endif
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
  __block NSError *localError = nil;
  __block BOOL success = NO;

  dispatch_sync(_shaderQueue, ^{
    success = [self _loadShaderWithNameInternal:name error:&localError];
  });

  if (error)
    *error = localError;
  return success;
}

- (BOOL)_loadShaderWithNameInternal:(NSString *)name error:(NSError **)error {
  __block BOOL alreadyLoaded = NO;
  __block NSError *localError = nil;

  // Simple log to confirm function called
  fprintf(stderr, "SC_DEBUG: _loadShaderWithNameInternal called for %s\n", [name UTF8String]);
  fflush(stderr);
  
  NSLog(@">>>>>>>>> _loadShaderWithNameInternal CALLED FOR: %@", name);

  // Logic from former loadShaderWithName:
  // Check for shader file
  NSString *path = [self pathForShader:name];
  if (!path) {
#ifdef DEBUG
    NSLog(@"[SHADER DEBUG] FAILED: Shader '%@' not found at any search path", name);
#endif
    localError = [NSError
        errorWithDomain:@"MetalRenderer"
                   code:MetalRendererErrorCodeShaderCompilationFailed
               userInfo:@{
                 NSLocalizedDescriptionKey :
                     [NSString stringWithFormat:@"Shader '%@' not found", name]
               }];
    if (error)
      *error = localError;
    return NO;
  }
#ifdef DEBUG
  NSLog(@"[SHADER DEBUG] Found shader file at: %@", path);
#endif

  // Check modification date
  NSDate *modDate = [self modificationDateForPath:path];
  NSDate *lastMod = self.shaderModificationDates[name];
  if (lastMod && [modDate isEqualToDate:lastMod] && self.pipelineCache[name]) {
#ifdef DEBUG
    NSLog(@"[SHADER DEBUG] Shader '%@' already loaded and unchanged", name);
#endif
    return YES; // Already loaded and unchanged
  }

  self.shaderModificationDates[name] = modDate;

  // Compile shader
  NSError *compileError = nil;
  NSString *source = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:&compileError];
  if (!source) {
    NSLog(@"[SHADER DEBUG] FAILED: Could not read shader file: %@", compileError);
    if (error)
      *error = compileError;
    return NO;
  }
  NSLog(@"[SHADER DEBUG] Read %lu bytes from shader file", (unsigned long)source.length);

  // Create library with full source
  NSLog(@"[SHADER DEBUG] Preparing shader source...");
  NSString *fullSource = [self prepareShaderSource:source forShader:name];
  NSLog(@"[SHADER DEBUG] Prepared source size: %lu bytes", (unsigned long)fullSource.length);
  NSLog(@"[SHADER DEBUG] First 200 chars of source: %@", [fullSource substringToIndex:MIN(200, fullSource.length)]);
  
  // Also write to file
  NSString *logLine = [NSString stringWithFormat:@"[SHADER] Loading shader: %@\n", name];
  NSData *logData = [logLine dataUsingEncoding:NSUTF8StringEncoding];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *debugLogPath = @"/tmp/shadercandy_debug.log";
  if (![fm fileExistsAtPath:debugLogPath]) {
    [logData writeToFile:debugLogPath atomically:YES];
  } else {
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:debugLogPath];
    if (handle) {
      [handle seekToEndOfFile];
      [handle writeData:logData];
      [handle closeFile];
    }
  }
  
  NSLog(@"[SHADER DEBUG] Creating Metal library for shader '%@'...", name);
  id<MTLLibrary> library = [self.device newLibraryWithSource:fullSource
                                                     options:nil
                                                       error:&compileError];
  NSLog(@"[SHADER DEBUG] Library creation returned: %@, error: %@", library, compileError);
  
  // EARLY RETURN if library failed
  if (!library) {
    NSLog(@"[SHADER DEBUG] EARLY EXIT: library is nil");
    if (compileError) {
      [self handleShaderCompileError:compileError
                           forShader:name
                              source:fullSource];
      if (error)
        *error = compileError;
    }
    return NO;
  }
  
  NSLog(@"[SHADER DEBUG] Metal library created successfully for: %@", name);
  
  // Debug: list ALL functions in the library
  NSArray *allFuncs = [library functionNames];
  NSLog(@"[SHADER DEBUG] Library '%@' has %lu functions: %@", name, (unsigned long)allFuncs.count, allFuncs);
  fprintf(stderr, "[SHADER] %s has %lu funcs\n", [name UTF8String], (unsigned long)allFuncs.count);
  fflush(stderr);

  self.libraryCache[name] = library;

// Create pipeline
  NSLog(@"[SHADER DEBUG] Creating pipeline state...");
  [@"Creating pipeline\n" writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"shadercandy_log.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  NSError *pipelineError = nil;
  MetalPipelineState *pipeline =
      [self createPipelineStateWithLibrary:library
                                 shaderName:name
                                      error:&pipelineError];
  if (pipelineError) {
    NSLog(@"[SHADER DEBUG] FAILED: Pipeline creation failed: %@", pipelineError);
    if (error)
      *error = pipelineError;
    return NO;
  }
  if (!pipeline) {
    NSLog(@"[SHADER DEBUG] FAILED: Pipeline is nil (missing vertex_main or fragment_main)");
    if (error) {
      *error = [NSError errorWithDomain:@"MetalRenderer"
                                   code:MetalRendererErrorCodeShaderCompilationFailed
                               userInfo:@{NSLocalizedDescriptionKey: @"Pipeline creation returned nil"}];
    }
    return NO;
  }
  NSLog(@"[SHADER DEBUG] Pipeline state created successfully");

  self.pipelineCache[name] = pipeline;
  self.currentPipeline = pipeline;
  self.activeShaderName = name;

  NSLog(@"MetalRenderer: Loaded shader '%@'", name);

  if ([self.delegate respondsToSelector:@selector(metalRenderer:
                                            didReloadShadersWithName:)]) {
    __block MetalRenderer *blockSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [blockSelf.delegate metalRenderer:blockSelf
               didReloadShadersWithName:name];
    });
  }

  return YES;
}

- (NSString *)pathForShader:(NSString *)name {
  return [self findResourcePath:name ofType:@"metal" subDir:@"shaders"];
}

- (NSDate *)modificationDateForPath:(NSString *)path {
  if (!path)
    return nil;
  NSDictionary *attrs =
      [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
  return [attrs fileModificationDate];
}

- (NSString *)findResourcePath:(NSString *)name
                        ofType:(NSString *)type
                        subDir:(NSString *)subDir {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSLog(@"MetalRenderer: bundleForClass returns: %@, resourcePath: %@, bundlePath: %@", bundle, bundle.resourcePath, bundle.bundlePath);
  
  NSString *path = [bundle pathForResource:name ofType:type inDirectory:subDir];
  if (path)
    return path;

  // Also try mainBundle (important for screensaver/player contexts)
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSLog(@"MetalRenderer: mainBundle: %@, resourcePath: %@", mainBundle, mainBundle.resourcePath);
  path = [mainBundle pathForResource:name ofType:type inDirectory:subDir];
  if (path)
    return path;
  
  // Also try root (no subdirectory) - CMake flattens bundle structure
  path = [bundle pathForResource:name ofType:type];
  if (path)
    return path;
  path = [mainBundle pathForResource:name ofType:type];
  if (path)
    return path;

  // Fallback to manual search
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *searchPaths = @[
    [[bundle resourcePath] stringByAppendingPathComponent:subDir ?: @""],
    [bundle.bundlePath stringByAppendingPathComponent:subDir ?: @""],
    [[mainBundle resourcePath] stringByAppendingPathComponent:subDir ?: @""],
    [[mainBundle bundlePath] stringByAppendingPathComponent:subDir ?: @""],
    [[fm currentDirectoryPath] stringByAppendingPathComponent:subDir ?: @""],
    [[fm currentDirectoryPath] stringByAppendingPathComponent:@"src/core"],
    [[fm currentDirectoryPath] stringByAppendingPathComponent:@"src/metal"],
    [fm currentDirectoryPath]
  ];

  for (NSString *basePath in searchPaths) {
    NSString *check = [[basePath stringByAppendingPathComponent:name]
        stringByAppendingPathExtension:type];
    if ([fm fileExistsAtPath:check]) {
      NSLog(@"MetalRenderer: Found resource %@.%@ at %@", name, type, check);
      return check;
    }

    // Check subdirectories
    for (NSString *sub in
         @[ @"base", @"effects", @"audio", @"music", @"neural" ]) {
      check = [[basePath stringByAppendingPathComponent:sub]
          stringByAppendingPathComponent:
              [name stringByAppendingPathExtension:type]];
      if ([fm fileExistsAtPath:check]) {
        NSLog(@"MetalRenderer: Found resource %@.%@ in subDir %@ at %@", name,
              type, sub, check);
        return check;
      }
    }
  }
  NSLog(@"MetalRenderer Error: Could not find resource %@.%@ in subDir %@",
        name, type, subDir);
  return nil;
}

- (NSString *)prepareShaderSource:(NSString *)source
                        forShader:(NSString *)shaderName {
  NSMutableString *fullSource = [NSMutableString string];

  // Prepend Metal standard library
  [fullSource
      appendString:@"#include <metal_stdlib>\nusing namespace metal;\n\n"];

  // Load and prepend interop header (Cached)
  if (!self.cachedInteropHeader) {
    NSString *path = [self findResourcePath:@"ShaderInterop"
                                     ofType:@"h"
                                     subDir:@"shaders"];
    if (path) {
      self.cachedInteropHeader =
          [NSString stringWithContentsOfFile:path
                                    encoding:NSUTF8StringEncoding
                                       error:nil];
    }
  }
  if (self.cachedInteropHeader) {
    [fullSource appendString:self.cachedInteropHeader];
    [fullSource appendString:@"\n\n"];
  }

  // Load and prepend utils (Cached & Cleaned)
  if (!self.cachedUtilsSource) {
    NSString *path = [self findResourcePath:@"utils"
                                     ofType:@"metal"
                                     subDir:@"shaders"];
    if (path) {
      NSString *rawUtils =
          [NSString stringWithContentsOfFile:path
                                    encoding:NSUTF8StringEncoding
                                       error:nil];
      if (rawUtils) {
        NSMutableString *cleaned = [rawUtils mutableCopy];
        [cleaned replaceOccurrencesOfString:@"#include <metal_stdlib>\n"
                                 withString:@""
                                    options:0
                                      range:NSMakeRange(0, cleaned.length)];
        [cleaned replaceOccurrencesOfString:@"using namespace metal;\n"
                                 withString:@""
                                    options:0
                                      range:NSMakeRange(0, cleaned.length)];
        self.cachedUtilsSource = cleaned;
      }
    }
  }
  if (self.cachedUtilsSource) {
    [fullSource appendString:self.cachedUtilsSource];
    // Make ShaderUtils namespace available to all shaders
    [fullSource appendString:@"\nusing namespace ShaderUtils;\n\n"];
  }

  // Add vertex shader wrapper
  [fullSource
      appendString:@"vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n"
                   @"    VertexOut out;\n"
                   @"    out.position = float4(in.position, 0.0, 1.0);\n"
                   @"    out.texCoord = in.texCoord;\n"
                   @"    return out;\n"
                   @"}\n\n"];

  // Add the main shader source
  NSMutableString *cleanedSource = [source mutableCopy];

  // Robustly remove ShaderInterop.h include (ignoring whitespace and quote
  // style, and potential path prefixes)
  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:
          @"#\\s*include\\s+[\"<](?:.*/)?ShaderInterop\\.h[\">]"
                           options:NSRegularExpressionCaseInsensitive
                             error:nil];
  [regex replaceMatchesInString:cleanedSource
                        options:0
                          range:NSMakeRange(0, cleanedSource.length)
                   withTemplate:@""];

  // As well as utils.metal, just in case
  regex = [NSRegularExpression
      regularExpressionWithPattern:
          @"#\\s*include\\s+[\"<](?:.*/)?utils\\.metal[\">]"
                           options:NSRegularExpressionCaseInsensitive
                             error:nil];
  [regex replaceMatchesInString:cleanedSource
                        options:0
                          range:NSMakeRange(0, cleanedSource.length)
                   withTemplate:@""];

  // Remove any "using namespace ShaderUtils;" statements since we add it after utils
  regex = [NSRegularExpression
      regularExpressionWithPattern:
          @"using\\s+namespace\\s+ShaderUtils\\s*;"
                           options:NSRegularExpressionCaseInsensitive
                             error:nil];
  [regex replaceMatchesInString:cleanedSource
                        options:0
                          range:NSMakeRange(0, cleanedSource.length)
                   withTemplate:@""];

  [fullSource appendString:cleanedSource];

  // Clean up any double newlines or trailing whitespace if needed
  // ...

  return fullSource;
}

- (void)handleShaderCompileError:(NSError *)error
                       forShader:(NSString *)name
                          source:(NSString *)source {
  NSLog(@"ShaderCandy: Failed to compile shader '%@': %@", name, error);

  // Write failed shader to home directory for debugging
  [self writeFailedShaderToFile:source
                       fileName:[NSString
                                    stringWithFormat:@"%@_failed.metal", name]];

  // Write error to file to bypass <private> log redaction
  NSString *homePath = NSHomeDirectory();
  NSString *errorPath =
      [homePath stringByAppendingPathComponent:@"shader_error.txt"];
  NSString *errorString =
      [NSString stringWithFormat:@"Shader: %@\nError: %@", name,
                                 error.localizedDescription];
  [errorString writeToFile:errorPath
                atomically:YES
                  encoding:NSUTF8StringEncoding
                     error:nil];

  MetalRendererError *rendererError = [MetalRendererError
      shaderErrorWithMessage:
          [NSString stringWithFormat:@"Shader compilation failed: %@",
                                     error.localizedDescription]
               compilerError:error.localizedDescription
                  shaderName:name
                  lineNumber:0];
  [_errorLog addObject:rendererError];

  if ([_delegate respondsToSelector:@selector(metalRenderer:
                                          didEncounterError:)]) {
    __block MetalRenderer *blockSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [blockSelf.delegate metalRenderer:blockSelf
                      didEncounterError:rendererError];
    });
  }
}

- (void)writeFailedShaderToFile:(NSString *)source
                       fileName:(NSString *)fileName {
  NSString *homePath = NSHomeDirectory();
  NSString *debugPath = [homePath stringByAppendingPathComponent:fileName];
  [source writeToFile:debugPath
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
  NSLog(@"Failed shader written to: %@", debugPath);
}

- (MetalPipelineState *)createPipelineStateWithLibrary:(id<MTLLibrary>)library
                                            shaderName:(NSString *)name
                                                 error:(NSError **)error {
  MetalPipelineState *state =
      [[MetalPipelineState alloc] initWithShaderName:name];

  NSError *pipelineError = nil;

  // Main render pipeline - optional if we have a compute or particle pipeline
  id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
  id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragment_main"];

  NSLog(@">>>>> PIPELINE: vertexFunc=%p, fragmentFunc=%p for shader %@", vertexFunc, fragmentFunc, name);
  fprintf(stderr, ">>>> PIPELINE: v=%p, f=%p shader=%s\n", vertexFunc, fragmentFunc, [name UTF8String]);
  fflush(stderr);

  if (!vertexFunc || !fragmentFunc) {
    NSLog(@"Shader '%@' missing required functions: vertex_main=%@, fragment_main=%@",
          name, vertexFunc ? @"YES" : @"NO", fragmentFunc ? @"YES" : @"NO");
    if (error) {
      *error = [NSError errorWithDomain:@"MetalRenderer"
                                   code:MetalRendererErrorCodeShaderCompilationFailed
                               userInfo:@{NSLocalizedDescriptionKey :
                                            [NSString stringWithFormat:@"Shader '%@' missing vertex_main or fragment_main", name]}];
    }
    return nil;
  }

  MTLRenderPipelineDescriptor *desc =
      [[MTLRenderPipelineDescriptor alloc] init];
  desc.vertexFunction = vertexFunc;
  desc.fragmentFunction = fragmentFunc;
  desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
  desc.colorAttachments[0].blendingEnabled = YES;
  desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
  desc.colorAttachments[0].destinationRGBBlendFactor =
      MTLBlendFactorOneMinusSourceAlpha;

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

  state.renderPipeline =
      [_device newRenderPipelineStateWithDescriptor:desc
                                              error:&pipelineError];
  if (pipelineError) {
    NSLog(@"[PIPELINE ERROR] Failed to create render pipeline: %@", pipelineError);
    // Write to home directory
    [@"PIPELINE ERROR\n" writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"shadercandy_log.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if (error)
      *error = pipelineError;
    return nil;
  }
  NSLog(@"[PIPELINE OK] Render pipeline created successfully");
  [@"PIPELINE OK\n" writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"shadercandy_log.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];

  // Check for simulation pipeline
  id<MTLFunction> simFunc = [library newFunctionWithName:@"fragment_sim"];
  if (simFunc) {
    MTLRenderPipelineDescriptor *simDesc =
        [[MTLRenderPipelineDescriptor alloc] init];
    simDesc.vertexFunction = vertexFunc;
    simDesc.fragmentFunction = simFunc;
    simDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    state.simulationPipeline =
        [_device newRenderPipelineStateWithDescriptor:simDesc error:nil];
  }

  // Check for particle pipelines
  id<MTLFunction> computeFunc =
      [library newFunctionWithName:@"compute_particles"];
  if (computeFunc) {
    state.computePipeline =
        [_device newComputePipelineStateWithFunction:computeFunc error:nil];

    id<MTLFunction> vPartFunc =
        [library newFunctionWithName:@"vertex_particles"];
    id<MTLFunction> fPartFunc =
        [library newFunctionWithName:@"fragment_particles"];

    if (vPartFunc && fPartFunc) {
      MTLRenderPipelineDescriptor *pDesc =
          [[MTLRenderPipelineDescriptor alloc] init];
      pDesc.vertexFunction = vPartFunc;
      pDesc.fragmentFunction = fPartFunc;
      pDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
      pDesc.colorAttachments[0].blendingEnabled = YES;
      pDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
      pDesc.colorAttachments[0].sourceRGBBlendFactor =
          MTLBlendFactorSourceAlpha;
      state.particleRenderPipeline =
          [_device newRenderPipelineStateWithDescriptor:pDesc error:nil];
    }
  }

  return state;
}

- (nullable MetalPipelineState *)createPipelineForShader:(NSString *)name
                                                   error:(NSError **)error {
  id<MTLLibrary> library = _libraryCache[name];
  if (!library) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"MetalRenderer"
                     code:MetalRendererErrorCodeShaderCompilationFailed
                 userInfo:@{
                   NSLocalizedDescriptionKey : [NSString
                       stringWithFormat:@"Library not found for shader: %@",
                                        name]
                 }];
    }
    return nil;
  }

  return [self createPipelineStateWithLibrary:library
                                   shaderName:name
                                        error:error];
}

#pragma mark - Shader Discovery

- (NSArray<NSString *> *)availableShaderNames {
  NSMutableArray *shaders = [NSMutableArray array];
  NSMutableSet *foundNames = [NSMutableSet set];

  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSLog(@"MetalRenderer: bundleForClass resolved to: %@", bundle.bundlePath);
  NSFileManager *fm = [NSFileManager defaultManager];

  // List of paths to search for shaders
  // Also try [NSBundle mainBundle] as a fallback for screensaver/player contexts
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSArray *searchPaths = @[
    [[bundle resourcePath] stringByAppendingPathComponent:@"shaders"],
    [bundle resourcePath],
    [[bundle bundlePath] stringByAppendingPathComponent:@"shaders"],
    [[mainBundle resourcePath] stringByAppendingPathComponent:@"shaders"],
    [mainBundle resourcePath],
    [[mainBundle bundlePath] stringByAppendingPathComponent:@"shaders"],
    [[fm currentDirectoryPath] stringByAppendingPathComponent:@"shaders"]
  ];

  NSLog(@"MetalRenderer: Searching for shaders in %lu locations (mainBundle: %@)...", 
        (unsigned long)searchPaths.count, mainBundle.bundlePath);
  for (NSString *path in searchPaths) {
    NSLog(@"MetalRenderer:   Checking path: %@", path);
  }

  for (NSString *path in searchPaths) {
    if (!path)
      continue;

    // Simple directory listing
    NSError *error = nil;
    NSArray *files = [fm contentsOfDirectoryAtPath:path error:&error];
    if (files) {
      NSInteger metalCount = 0;
      for (NSString *fileName in files) {
        if ([fileName hasSuffix:@".metal"]) {
          [foundNames addObject:[fileName stringByDeletingPathExtension]];
          metalCount++;
        }
      }
      if (metalCount > 0) {
        NSLog(@"MetalRenderer: Found %ld .metal files in %@", (long)metalCount, path);
      }
    } else if (error) {
      NSLog(@"MetalRenderer: Error reading %@: %@", path, error);
    }

    // Also check subdirectories one level deep
    for (NSString *sub in
         @[ @"base", @"effects", @"audio", @"music", @"neural" ]) {
      NSString *subPath = [path stringByAppendingPathComponent:sub];
      files = [fm contentsOfDirectoryAtPath:subPath error:nil];
      if (files) {
        NSInteger metalCount = 0;
        for (NSString *fileName in files) {
          if ([fileName hasSuffix:@".metal"]) {
            [foundNames addObject:[fileName stringByDeletingPathExtension]];
            metalCount++;
          }
        }
        if (metalCount > 0) {
          NSLog(@"MetalRenderer: Found %ld .metal files in %@", (long)metalCount, subPath);
        }
      }
    }
  }

  // Filter excluded names
  for (NSString *name in foundNames) {
    if (![name isEqualToString:@"common"] && ![name isEqualToString:@"utils"] &&
        ![name isEqualToString:@"ShaderInterop"] &&
        ![name isEqualToString:@"bloom"] &&
        ![name isEqualToString:@"particles"] &&
        ![name isEqualToString:@"debug_overlay"] &&
        ![name hasSuffix:@"_failed"]) {
      [shaders addObject:name];
    }
  }

  [shaders sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  NSLog(@"Discovered %lu shaders: %@", (unsigned long)shaders.count, shaders);
  return [shaders copy];
}

- (NSDictionary<NSString *, NSNumber *> *)testAllShaders {
  NSArray<NSString *> *shaders = [self availableShaderNames];
  NSMutableDictionary *results = [NSMutableDictionary dictionary];
  
  NSLog(@"\n========== TESTING ALL SHADERS ==========");
  
  for (NSString *shaderName in shaders) {
    NSError *error = nil;
    BOOL success = [self loadShaderWithName:shaderName error:&error];
    results[shaderName] = @(success);
    
    if (success) {
      NSLog(@"  [OK] %@", shaderName);
    } else {
      NSLog(@"  [FAIL] %@ - %@", shaderName, error.localizedDescription ?: @"unknown error");
    }
  }
  
  NSInteger successCount = 0;
  NSInteger failCount = 0;
  for (NSString *name in results) {
    if ([results[name] boolValue]) {
      successCount++;
    } else {
      failCount++;
    }
  }
  
  NSLog(@"\n========== SHADER TEST RESULTS ==========");
  NSLog(@"Total: %lu, Passed: %ld, Failed: %ld", (unsigned long)shaders.count, (long)successCount, (long)failCount);
  
  if (failCount > 0) {
    NSLog(@"Failed shaders:");
    for (NSString *name in results) {
      if (![results[name] boolValue]) {
        NSLog(@"  - %@", name);
      }
    }
  }
  NSLog(@"==========================================\n");
  
  return [results copy];
}

- (BOOL)setActiveShader:(NSString *)name error:(NSError **)error {
  BOOL success = [self loadShaderWithName:name error:error];
  if (success) {
    _activeShaderName = name;
    _currentPipeline = self.pipelineCache[name];
  }
  return success;
}

- (BOOL)transitionToShaderNamed:(NSString *)name
                       duration:(NSTimeInterval)duration
                          error:(NSError **)error {
  if ([name isEqualToString:_activeShaderName])
    return YES;

  // Store current as previous
  _previousPipeline = _currentPipeline;
  _previousShaderName = _activeShaderName;

  // Load new shader
  BOOL success = [self loadShaderWithName:name error:error];
  if (!success) {
    _previousPipeline = nil;
    _previousShaderName = nil;
    return NO;
  }

  // Update state
  _activeShaderName = name;
  _currentPipeline = self.pipelineCache[name];

  // Start transition
  _isTransitioning = YES;
  _transitionAlpha = 0.0f;
  _transitionDuration = duration > 0 ? duration : 1.0;
  _transitionStartTime = [NSDate date];

  return YES;
}

- (BOOL)reloadCurrentShader:(NSError **)error {
  if (!_activeShaderName)
    return NO;
  [_pipelineCache removeObjectForKey:_activeShaderName];
  [_libraryCache removeObjectForKey:_activeShaderName];
  return [self loadShaderWithName:_activeShaderName error:error];
}

#pragma mark - Pipeline Pre-warming

- (void)prewarmPipelinesForShaders:(NSArray<NSString *> *)shaders {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    for (NSString *name in shaders) {
      // Use dispatch_sync on _shaderQueue only for cache check and triggering
      // load
      dispatch_sync(self.shaderQueue, ^{
        if (!self.pipelineCache[name]) {
          [self _loadShaderWithNameInternal:name error:nil];
        }
      });
    }
  });
}

#pragma mark - File Watching

- (void)setupFileWatcher {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *shadersPath =
      [[bundle resourcePath] stringByAppendingPathComponent:@"shaders"];

  NSLog(@"Setting up file watcher for: %@", shadersPath);

  int fd = open([shadersPath UTF8String], O_RDONLY);
  if (fd < 0) {
    NSLog(@"Failed to open shaders directory for file watching: %@",
          shadersPath);
    return;
  }

  _fileWatcherSource = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t)fd,
      DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE, _shaderQueue);

  dispatch_source_set_event_handler(_fileWatcherSource, ^{
    [self checkForShaderChanges];
  });

  dispatch_source_set_cancel_handler(_fileWatcherSource, ^{
    close(fd);
  });

  dispatch_resume(_fileWatcherSource);
  NSLog(@"File watcher setup complete");
}

- (void)checkForShaderChanges {
  if (!_hotReloadEnabled)
    return;

  NSDate *now = [NSDate date];
  if (_lastShaderCheckTime &&
      [now timeIntervalSinceDate:_lastShaderCheckTime] < 1.0) {
    return; // Check at most once per second
  }
  _lastShaderCheckTime = now;

  for (NSString *name in _shaderModificationDates.allKeys) {
    NSString *path = [self pathForShader:name];
    NSDate *modDate = [self modificationDateForPath:path];
    NSDate *lastMod = _shaderModificationDates[name];

    if (modDate && lastMod && ![modDate isEqualToDate:lastMod]) {
      NSLog(@"MetalRenderer: Detected change in shader '%@', reloading...",
            name);
      [_pipelineCache removeObjectForKey:name];
      [_libraryCache removeObjectForKey:name];
      [self _loadShaderWithNameInternal:name error:nil];
    }
  }
}

#pragma mark - Rendering

- (void)beginFrame {
  [_performanceReporter beginFrame];
  dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)endFrame {
  GPUFrameStats *stats = [_performanceReporter latestStats];
  _metrics.frameTimeMs = stats.frameTimeMs;
  _metrics.averageFPS = [_performanceReporter currentFPS];
  _metrics.currentFPS = [_performanceReporter currentFPS];
  _frameCount++;
  _metrics.gpuTimeMs = stats.gpuTimeMs;
  _metrics.cpuTimeMs = stats.cpuTimeMs;

  // Update thermal state periodically
  if (_frameCount % 60 == 0) {
    [self updateThermalState];
  }

  // Dropped frames check
  if (stats.frameTimeMs > 33.3) { // Below 30fps
    _metrics.droppedFrames++;
  }

  // Enhanced performance auto-scaling with dynamic resolution
  if (_autoScalingEnabled && _frameCount > 60) { // Wait for warm up
    float fps = _metrics.currentFPS;

    // Stage 0: Dynamic Resolution (highest impact)
    if (_dynamicResolutionEnabled && fps < _autoScaleFPSThreshold * 0.8) {
      // Reduce resolution scale
      _resolutionScale = MAX(0.5f, _resolutionScale - 0.05f);
      [self createTexturesForSize:_resources.viewportSize];
      NSLog(@"MetalRenderer: Auto-scale reducing resolution to %.0f%%",
            _resolutionScale * 100);
    } else if (_dynamicResolutionEnabled && fps > _preferredFPS - 5.0f &&
               _resolutionScale < 1.0f) {
      // Increase resolution scale
      _resolutionScale = MIN(1.0f, _resolutionScale + 0.02f);
      [self createTexturesForSize:_resources.viewportSize];
      NSLog(@"MetalRenderer: Auto-scale increasing resolution to %.0f%%",
            _resolutionScale * 100);
    }

    // Stage 1: Particle reduction
    if (fps < _autoScaleFPSThreshold) {
      if (_particleConfig.count > 1000) {
        _particleConfig.count =
            MAX(1000, (NSInteger)(_particleConfig.count * 0.9));
      } else if (_bloomConfig.enabled &&
                 _bloomConfig.quality > MetalBloomQualityLow) {
        _bloomConfig.quality =
            (MetalBloomQuality)((int)_bloomConfig.quality - 1);
      }
    } else if (fps > (_preferredFPS - 2.0f)) {
      if (_particleConfig.count < 100000) {
        _particleConfig.count =
            MIN(100000, (NSInteger)(_particleConfig.count * 1.05));
      } else if (_bloomConfig.enabled &&
                 _bloomConfig.quality < MetalBloomQualityUltra) {
        _bloomConfig.quality =
            (MetalBloomQuality)((int)_bloomConfig.quality + 1);
      }
    }

    _particleConfig.count = [[MetalSharedState sharedState]
        syncParticleCount:_particleConfig.count];
  }

  // Update memory usage metric
  _metrics.memoryUsageBytes = _resourcePool.currentMemoryUsageBytes;

  if ([_delegate respondsToSelector:@selector(metalRenderer:
                                           didUpdateMetrics:)]) {
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
  uniforms->alpha =
      _currentPipeline == _previousPipeline ? 1.0f : 1.0f; // Placeholder

  // Update Audio Uniforms
  if (_audioReactivityEnabled && _audioInput) {
    ShaderCandy::Audio::AudioData audioData = _audioInput->getCurrentData();
    uniforms->volume = audioData.volumeSmoothed;
    uniforms->bass = audioData.bass;
    uniforms->mid = audioData.mid;
    uniforms->treble = audioData.treble;
    uniforms->beat = audioData.beat ? 1.0f : 0.0f;

    ShaderCandy::Audio::Utils::packAudioForShader(audioData,
                                                  uniforms->audioData, 256);
  } else {
    uniforms->volume = 0;
    uniforms->bass = 0;
    uniforms->mid = 0;
    uniforms->treble = 0;
    uniforms->beat = 0;
    memset(uniforms->audioData, 0, sizeof(uniforms->audioData));
  }
  uniforms->resolution = (vector_float2){(float)_resources.viewportSize.width,
                                         (float)_resources.viewportSize.height};

  // Mouse position
  uniforms->mouse = (vector_float2){
      (float)(mousePos.x / (_resources.viewportSize.width ?: 1)),
      (float)(mousePos.y / (_resources.viewportSize.height ?: 1))};

  // Date (Update every 60 frames to save CPU)
  if (_frameCount % 60 == 0) {
    _dateComponents =
        [_calendar components:NSCalendarUnitYear | NSCalendarUnitMonth |
                              NSCalendarUnitDay | NSCalendarUnitHour |
                              NSCalendarUnitMinute | NSCalendarUnitSecond
                     fromDate:[NSDate date]];
  }

  uniforms->date = (vector_float4){
      (float)_dateComponents.year, (float)_dateComponents.month,
      (float)_dateComponents.day,
      (float)(_dateComponents.hour * 3600 + _dateComponents.minute * 60 +
              _dateComponents.second + (float)(time - floor(time)))};

  uniforms->frame = (int32_t)_frameCount;
  uniforms->deltaTime = 1.0f / _preferredFPS;
  uniforms->alpha = 1.0f;

  // Performance metrics
  uniforms->gpuTime = _metrics.gpuTimeMs;
  uniforms->cpuTime = _metrics.cpuTimeMs;
  uniforms->fps = (float)_metrics.currentFPS;

  // Update Game State (Dummy values for capman/parity)
  uniforms->gameTime = (float)time;
  uniforms->playerPos = (vector_float2){(float)sin(time * 0.5) * 0.5f,
                                        (float)cos(time * 0.3) * 0.5f};
  uniforms->ghostPos[0] = (vector_float2){0.5f, 0.5f};
  uniforms->ghostPos[1] = (vector_float2){-0.5f, 0.5f};
  uniforms->ghostPos[2] = (vector_float2){0.5f, -0.5f};
  uniforms->ghostPos[3] = (vector_float2){-0.5f, -0.5f};
  uniforms->score = 1000.0f;
  uniforms->lives = 3.0f;
  uniforms->level = 1.0f;
}

- (void)renderToDrawable:(id<CAMetalDrawable>)drawable
    renderPassDescriptor:(MTLRenderPassDescriptor *)descriptor {
  if (!_currentPipeline || !_commandQueue) {
    return;
  }

  // Ensure we have a valid render pipeline
  if (!_currentPipeline.renderPipeline) {
    NSLog(@"MetalRenderer: Cannot render - no valid render pipeline for shader '%@'",
          _activeShaderName ?: @"unknown");
    return;
  }

  [self beginFrame];

  id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

  // Semaphore management
  __block dispatch_semaphore_t semaphore = _inFlightSemaphore;
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(semaphore);
  }];

  // Get uniforms
  NSUInteger bufferIndex = _frameCount % 3;
  uint8_t *bufferPtr = (uint8_t *)_resources.uniformBuffer.contents;
  Uniforms *uniforms = (Uniforms *)(bufferIndex * sizeof(Uniforms) + bufferPtr);
  
  // Determine if we need the advanced offscreen pipeline
  BOOL needsOffscreen = _bloomConfig.enabled || _hdrEnabled ||
                        _neuralStyleEnabled || _isTransitioning;

  if (!needsOffscreen) {
    // 1. Optional Simulation Pass
    if (_currentPipeline.simulationPipeline) {
      [self performSimulationPassWithCommandBuffer:commandBuffer
                                          uniforms:uniforms
                                       bufferIndex:bufferIndex];
    }

    // 2. Direct Render to Screen
    // Ensure the descriptor (which points to drawable) is used
    descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

    [self renderSimpleToDrawable:drawable
                   commandBuffer:commandBuffer
                renderDescriptor:descriptor
                        uniforms:uniforms
                     bufferIndex:bufferIndex];
  } else {
    // Advanced Multi-Pass Flow
    // 1. Simulation Pass
    if (_currentPipeline.simulationPipeline) {
      [self performSimulationPassWithCommandBuffer:commandBuffer
                                          uniforms:uniforms
                                       bufferIndex:bufferIndex];
    }

    // 2. Scene Rendering Pass (render to offscreen HDR texture)
    MTLRenderPassDescriptor *hdrPassDesc =
        [MTLRenderPassDescriptor renderPassDescriptor];
    hdrPassDesc.colorAttachments[0].texture = _resources.sceneTexture;
    hdrPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    hdrPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    hdrPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

    if (_bloomConfig.enabled) {
      [self renderWithBloomToDrawable:nil
                        commandBuffer:commandBuffer
                     renderDescriptor:hdrPassDesc
                             uniforms:uniforms
                          bufferIndex:bufferIndex];
    } else {
      [self renderSimpleToDrawable:nil
                     commandBuffer:commandBuffer
                  renderDescriptor:hdrPassDesc
                          uniforms:uniforms
                       bufferIndex:bufferIndex];
    }

    // 2b. Transition cross-fade
    // When _isTransitioning the render above has drawn the CURRENT pipeline
    // into sceneTexture. We now render the PREVIOUS pipeline into
    // transitionTexture, then composite them using the smoothstep crossfade
    // pipeline onto the drawable.
    if (_isTransitioning && _previousPipeline && _resources.transitionTexture) {
      // --- Advance alpha ---
      NSTimeInterval elapsed =
          [[NSDate date] timeIntervalSinceDate:_transitionStartTime];
      float t = (float)(elapsed / _transitionDuration);
      // Smoothstep: t = 3t² - 2t³
      t = MAX(0.0f, MIN(1.0f, t));
      _transitionAlpha = t * t * (3.0f - 2.0f * t);

      // --- Render previous shader into transitionTexture ---
      MetalPipelineState *savedCurrent = _currentPipeline;
      _currentPipeline = _previousPipeline;

      MTLRenderPassDescriptor *prevPassDesc =
          [MTLRenderPassDescriptor renderPassDescriptor];
      prevPassDesc.colorAttachments[0].texture = _resources.transitionTexture;
      prevPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
      prevPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
      prevPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

      [self renderSimpleToDrawable:nil
                     commandBuffer:commandBuffer
                  renderDescriptor:prevPassDesc
                          uniforms:uniforms
                       bufferIndex:bufferIndex];

      _currentPipeline = savedCurrent;

      // --- Composite: mix(transitionTexture, sceneTexture, alpha) → drawable ---
      // transitionTexture = outgoing (alpha = 1 - _transitionAlpha)
      // sceneTexture      = incoming (alpha = _transitionAlpha)
      id<MTLRenderPipelineState> crossfade = [self crossfadePipeline];
      if (crossfade) {
        MTLRenderPassDescriptor *compositeDesc =
            [MTLRenderPassDescriptor renderPassDescriptor];
        compositeDesc.colorAttachments[0].texture = drawable.texture;
        compositeDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        compositeDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        compositeDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

        float alpha = _transitionAlpha;
        id<MTLRenderCommandEncoder> crossfadeEncoder =
            [commandBuffer renderCommandEncoderWithDescriptor:compositeDesc];
        [crossfadeEncoder setRenderPipelineState:crossfade];
        [crossfadeEncoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
        // texture(0) = outgoing (previous), texture(1) = incoming (current)
        [crossfadeEncoder setFragmentTexture:_resources.transitionTexture atIndex:0];
        [crossfadeEncoder setFragmentTexture:_resources.sceneTexture atIndex:1];
        [crossfadeEncoder setFragmentSamplerState:_resources.samplerState atIndex:0];
        [crossfadeEncoder setFragmentBytes:&alpha length:sizeof(float) atIndex:1];
        [crossfadeEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                     indexCount:6
                                      indexType:MTLIndexTypeUInt16
                                    indexBuffer:_resources.indexBuffer
                              indexBufferOffset:0];
        [crossfadeEncoder endEncoding];
      }

      // --- End transition when alpha reaches 1 ---
      if (_transitionAlpha >= 1.0f) {
        _isTransitioning = NO;
        _previousPipeline = nil;
        _previousShaderName = nil;
        _transitionStartTime = nil;
      }

      // Skip the HDR tone-map below; we already wrote to drawable.texture
      goto transition_complete;
    }

    id<MTLTexture> currentSource = _resources.sceneTexture;

    // 3. Neural Style
    if (_neuralStyleEnabled &&
        [[NeuralStyleEngine sharedEngine] currentModel]) {
      id<MTLTexture> neuralResult =
          [[NeuralStyleEngine sharedEngine] applyStyle:currentSource
                                         commandBuffer:commandBuffer
                                              strength:_styleStrength];
      if (neuralResult)
        currentSource = neuralResult;
    }

    // 4. Final Tone Map to Screen
    [[HDRPipeline sharedPipeline] toneMapHDRTexture:currentSource
                                       toSDRTexture:drawable.texture
                                      commandBuffer:commandBuffer];
  }

transition_complete:;

  // 5. Particles (overlaid on top)
  if (_particleConfig.enabled && _currentPipeline.computePipeline) {
    [self renderParticlesWithCommandBuffer:commandBuffer
                                  uniforms:uniforms
                               bufferIndex:bufferIndex];
  }

  // 6. Debug Overlay
  if (_showDebugOverlay) {
    [self renderDebugOverlayWithCommandBuffer:commandBuffer
                                   descriptor:descriptor
                                     uniforms:uniforms
                                  bufferIndex:bufferIndex];
  }

  // Update soundscape metrics
  SoundscapeMetrics sMetrics;
  sMetrics.intensity = uniforms->intensity;
  sMetrics.speed = uniforms->speed;
  sMetrics.visualComplexity =
      (_particleConfig.enabled ? (float)_particleConfig.count / 100000.0f
                               : 0.0f) +
      (_bloomConfig.enabled ? 0.5f : 0.0f);
  sMetrics.activity = 0.0f; // Could be mouse delta

  SoundscapeGenerator *gen = [SoundscapeGenerator sharedGenerator];
  if (gen.enabled) {
    if (![gen start]) {
      // Failed to start
    }
    [gen updateWithMetrics:sMetrics];
  }

  // Optional screenshot capture hook.
  //
  // The standalone app installs a one-shot block via associated objects. We
  // consume and clear it here on the render thread, allowing the hook to encode
  // a blit copy *before* presenting the drawable.
  SCScreenshotEncodeHook screenshotHook = nil;
  @synchronized(self) {
    screenshotHook = (SCScreenshotEncodeHook)objc_getAssociatedObject(
        self, @selector(sc_screenshotHook));
    if (screenshotHook) {
      objc_setAssociatedObject(self, @selector(sc_screenshotHook), nil,
                               OBJC_ASSOCIATION_ASSIGN);
    }
  }
  if (screenshotHook) {
    screenshotHook(commandBuffer, drawable.texture);
  }

  [commandBuffer presentDrawable:drawable];
  [_performanceReporter endFrameWithCommandBuffer:commandBuffer];
  [commandBuffer commit];
  [self endFrame];
}

- (void)renderToTexture:(id<MTLTexture>)texture {
  if (!_currentPipeline || !_currentPipeline.renderPipeline || !_commandQueue ||
      !texture)
    return;

  [self beginFrame];

  id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

  // Semaphore management
  __block dispatch_semaphore_t semaphore = _inFlightSemaphore;
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(semaphore);
  }];

  // Get uniforms
  if (!_resources.uniformBuffer || !_resources.uniformBuffer.contents) {
    NSLog(@"MetalRenderer Error: Uniform buffer not ready for renderToTexture");
    [self endFrame];
    return;
  }

  NSUInteger bufferIndex = _frameCount % 3;
  uint8_t *bufferPtr = (uint8_t *)_resources.uniformBuffer.contents;
  Uniforms *uniforms = (Uniforms *)(bufferIndex * sizeof(Uniforms) + bufferPtr);

  // Create render descriptor for the target texture
  MTLRenderPassDescriptor *descriptor =
      [MTLRenderPassDescriptor renderPassDescriptor];
  descriptor.colorAttachments[0].texture = texture;
  descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
  descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
  descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

  // Shared Logic with renderToDrawable (simplified)
  // 1. Simulation Pass
  if (_currentPipeline.simulationPipeline) {
    [self performSimulationPassWithCommandBuffer:commandBuffer
                                        uniforms:uniforms
                                     bufferIndex:bufferIndex];
  }

  // 2. Main Render Pass
  // Check if we need bloom/HDR flow or simple flow
  BOOL needsOffscreen = _bloomConfig.enabled || _hdrEnabled ||
                        _neuralStyleEnabled || _isTransitioning;

  if (needsOffscreen) {
    // Logic for advanced pipeline (Bloom/HDR)
    // Render to internal scene texture first
    MTLRenderPassDescriptor *sceneDesc =
        [MTLRenderPassDescriptor renderPassDescriptor];
    sceneDesc.colorAttachments[0].texture = _resources.sceneTexture;
    sceneDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    sceneDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    sceneDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

    if (_bloomConfig.enabled) {
      [self renderWithBloomToDrawable:nil
                        commandBuffer:commandBuffer
                     renderDescriptor:sceneDesc
                             uniforms:uniforms
                          bufferIndex:bufferIndex];
    } else {
      [self renderSimpleToDrawable:nil
                     commandBuffer:commandBuffer
                  renderDescriptor:sceneDesc
                          uniforms:uniforms
                       bufferIndex:bufferIndex];
    }

    // Final Tone Map / Copy to Output Texture
    id<MTLTexture> currentSource = _resources.sceneTexture;
    // (Skipping neural/transition complexity for simplicity in screenshot tool
    // for now, can add later)

    // Tone map to the output texture
    [[HDRPipeline sharedPipeline] toneMapHDRTexture:currentSource
                                       toSDRTexture:texture
                                      commandBuffer:commandBuffer];

  } else {
    // Direct render to output texture
    [self renderSimpleToDrawable:nil // No drawable logic needed inside
                   commandBuffer:commandBuffer
                renderDescriptor:descriptor
                        uniforms:uniforms
                     bufferIndex:bufferIndex];
  }

  // 3. Particles
  if (_particleConfig.enabled && _currentPipeline.computePipeline) {
    [self renderParticlesWithCommandBuffer:commandBuffer
                                  uniforms:uniforms
                               bufferIndex:bufferIndex];
  }

  // No debug overlay for screenshots usually

  [_performanceReporter endFrameWithCommandBuffer:commandBuffer];
  [commandBuffer commit];
  [self endFrame];
}

- (void)renderSimpleToDrawable:(id<CAMetalDrawable>)drawable
                   commandBuffer:(id<MTLCommandBuffer>)commandBuffer
                renderDescriptor:(MTLRenderPassDescriptor *)descriptor
                        uniforms:(Uniforms *)uniforms
                     bufferIndex:(NSUInteger)bufferIndex {
  // Check if we have a valid pipeline
  if (!_currentPipeline.renderPipeline) {
    return;
  }

  descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

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

  // Also provide the simulation textures for feedback-based shaders
  if (_currentPipeline.simulationPipeline) {
    [encoder setFragmentTexture:_resources.simulationTextureA atIndex:1];
    [encoder setFragmentTexture:_resources.simulationTextureB atIndex:2];
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

- (void)performSimulationPassWithCommandBuffer:
            (id<MTLCommandBuffer>)commandBuffer
                                      uniforms:(Uniforms *)uniforms
                                   bufferIndex:(NSUInteger)bufferIndex {
  // Check if we have a valid simulation pipeline
  if (!_currentPipeline.simulationPipeline) {
    NSLog(@"MetalRenderer: No simulation pipeline available, skipping simulation");
    return;
  }

  // Ping-pong swap logic
  id<MTLTexture> source = _resources.simulationTextureA;
  id<MTLTexture> dest = _resources.simulationTextureB;

  // Swap every frame: frame 0 (A->B), frame 1 (B->A), etc.
  if (_frameCount % 2 != 0) {
    source = _resources.simulationTextureB;
    dest = _resources.simulationTextureA;
  }

  MTLRenderPassDescriptor *simPass =
      [MTLRenderPassDescriptor renderPassDescriptor];
  simPass.colorAttachments[0].texture = dest;
  simPass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
  simPass.colorAttachments[0].storeAction = MTLStoreActionStore;

  id<MTLRenderCommandEncoder> encoder =
      [commandBuffer renderCommandEncoderWithDescriptor:simPass];
  [encoder setRenderPipelineState:_currentPipeline.simulationPipeline];
  [encoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
  [encoder setFragmentBuffer:_resources.uniformBuffer
                      offset:bufferIndex * sizeof(Uniforms)
                     atIndex:0];
  [encoder setFragmentTexture:source atIndex:0];
  if (_resources.samplerState) {
    [encoder setFragmentSamplerState:_resources.samplerState atIndex:0];
  }

  [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                      indexCount:6
                       indexType:MTLIndexTypeUInt16
                     indexBuffer:_resources.indexBuffer
               indexBufferOffset:0];
  [encoder endEncoding];

  // For the main pass, we'll want to sample from the new 'dest'
  _resources.mainTexture = dest;
}

- (void)renderWithBloomToDrawable:(id<CAMetalDrawable>)drawable
                    commandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 renderDescriptor:(MTLRenderPassDescriptor *)descriptor
                         uniforms:(Uniforms *)uniforms
                      bufferIndex:(NSUInteger)bufferIndex {
  // Check if we have a valid pipeline
  if (!_currentPipeline.renderPipeline) {
    NSLog(@"MetalRenderer: No render pipeline available, skipping render");
    return;
  }

  // Pre-check all bloom pipelines before starting GPU work.
  // If any are missing, fall back to simple rendering to avoid a blank frame.
  id<MTLRenderPipelineState> bloomThresh =
      [self bloomPipeline:@"bloom_threshold"];
  id<MTLRenderPipelineState> bloomBlurH = [self bloomPipeline:@"bloom_blur_h"];
  id<MTLRenderPipelineState> bloomBlurV = [self bloomPipeline:@"bloom_blur_v"];
  id<MTLRenderPipelineState> bloomCombine =
      [self bloomPipeline:@"bloom_combine"];

  if (!bloomThresh || !bloomBlurH || !bloomBlurV || !bloomCombine) {
    NSLog(@"MetalRenderer: Bloom pipelines unavailable, falling back to simple render");
    // Disable bloom so we don't keep hitting this path
    _bloomConfig.enabled = NO;
    [self renderSimpleToDrawable:drawable
                  commandBuffer:commandBuffer
               renderDescriptor:descriptor
                       uniforms:uniforms
                    bufferIndex:bufferIndex];
    return;
  }

  // Scene pass to offscreen texture
  MTLRenderPassDescriptor *sceneDesc =
      [MTLRenderPassDescriptor renderPassDescriptor];
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
  MTLRenderPassDescriptor *bloomDesc =
      [MTLRenderPassDescriptor renderPassDescriptor];
  bloomDesc.colorAttachments[0].texture = _resources.bloomTextureA;
  bloomDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
  bloomDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

  id<MTLRenderCommandEncoder> threshEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:bloomDesc];
  [threshEncoder setRenderPipelineState:bloomThresh];
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
  [blurHEncoder setRenderPipelineState:bloomBlurH];
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
  [blurVEncoder setRenderPipelineState:bloomBlurV];
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
      [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
  [finalEncoder setRenderPipelineState:bloomCombine];
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

- (id<MTLFunction>)loadSystemShaderWithName:(NSString *)functionName {
  return [_device newDefaultLibrary]
             ? [[_device newDefaultLibrary] newFunctionWithName:functionName]
             : nil;
}

// ---------------------------------------------------------------------------
// Crossfade pipeline — compiled once, cached in an ivar.
// Fragment function: mix(outgoing, incoming, alpha)
//   texture(0) = outgoing (previous shader)
//   texture(1) = incoming (current shader)
//   buffer(1)  = float alpha
// ---------------------------------------------------------------------------
- (id<MTLRenderPipelineState>)crossfadePipeline {
  if (_crossfadePipeline)
    return _crossfadePipeline;

  NSString *source =
    @"#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "struct VertexIn  { float2 position [[attribute(0)]]; float2 texCoord [[attribute(1)]]; };\n"
     "struct VertexOut { float4 position [[position]]; float2 texCoord; };\n"
     "vertex VertexOut crossfade_vertex(VertexIn in [[stage_in]]) {\n"
     "    VertexOut out;\n"
     "    out.position = float4(in.position, 0.0, 1.0);\n"
     "    out.texCoord = in.texCoord;\n"
     "    return out;\n"
     "}\n"
     "fragment float4 crossfade_fragment(VertexOut in [[stage_in]],\n"
     "    texture2d<float> outgoing [[texture(0)]],\n"
     "    texture2d<float> incoming [[texture(1)]],\n"
     "    sampler samp             [[sampler(0)]],\n"
     "    constant float& alpha    [[buffer(1)]]) {\n"
     "    float4 a = outgoing.sample(samp, in.texCoord);\n"
     "    float4 b = incoming.sample(samp, in.texCoord);\n"
     "    return mix(a, b, alpha);\n"
     "}\n";

  NSError *err = nil;
  id<MTLLibrary> lib = [_device newLibraryWithSource:source options:nil error:&err];
  if (!lib) {
    NSLog(@"MetalRenderer: crossfade shader compile failed: %@", err);
    return nil;
  }

  MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
  desc.vertexFunction   = [lib newFunctionWithName:@"crossfade_vertex"];
  desc.fragmentFunction = [lib newFunctionWithName:@"crossfade_fragment"];
  desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

  MTLVertexDescriptor *vd = [MTLVertexDescriptor vertexDescriptor];
  vd.attributes[0].format      = MTLVertexFormatFloat2;
  vd.attributes[0].offset      = 0;
  vd.attributes[0].bufferIndex = 0;
  vd.attributes[1].format      = MTLVertexFormatFloat2;
  vd.attributes[1].offset      = 8;
  vd.attributes[1].bufferIndex = 0;
  vd.layouts[0].stride         = 16;
  desc.vertexDescriptor = vd;

  NSError *pipeErr = nil;
  _crossfadePipeline = [_device newRenderPipelineStateWithDescriptor:desc
                                                               error:&pipeErr];
  if (pipeErr)
    NSLog(@"MetalRenderer: crossfade pipeline creation failed: %@", pipeErr);

  return _crossfadePipeline;
}

- (id<MTLRenderPipelineState>)bloomPipeline:(NSString *)functionName {
  static NSMutableDictionary *cache = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [NSMutableDictionary dictionary];
  });

  id<MTLRenderPipelineState> cached = cache[functionName];
  if (cached)
    return cached;

  // bloom.metal lives in shaders/effects/ or shaders/ - try multiple paths
  NSArray *searchDirs = @[@"shaders/effects", @"shaders", @""];
  NSString *path = nil;
  for (NSString *dir in searchDirs) {
    path = [self findResourcePath:@"bloom" ofType:@"metal" subDir:dir];
    if (path) break;
  }
  
  if (!path) {
    NSLog(@"MetalRenderer Error: Failed to find bloom.metal");
    return nil;
  }

  NSString *source = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  if (!source) {
    return nil;
  }

  NSString *fullSource = [self prepareShaderSource:source forShader:@"bloom"];
  NSError *error = nil;
  id<MTLLibrary> library = [_device newLibraryWithSource:fullSource
                                                 options:nil
                                                   error:&error];
  if (error || !library) {
    NSLog(@"MetalRenderer Error: Failed to compile bloom.metal: %@", error);
    return nil;
  }

  id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
  id<MTLFunction> fragmentFunc = [library newFunctionWithName:functionName];
  if (!vertexFunc || !fragmentFunc)
    return nil;

  MTLRenderPipelineDescriptor *desc =
      [[MTLRenderPipelineDescriptor alloc] init];
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

  id<MTLRenderPipelineState> pipeline =
      [_device newRenderPipelineStateWithDescriptor:desc error:nil];
  if (pipeline) {
    cache[functionName] = pipeline;
  }
  return pipeline;
}

- (void)renderParticlesWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                uniforms:(Uniforms *)uniforms
                             bufferIndex:(NSUInteger)bufferIndex {
  if (!_currentPipeline.computePipeline)
    return;

  id<MTLComputeCommandEncoder> computeEncoder =
      [commandBuffer computeCommandEncoder];
  [computeEncoder setComputePipelineState:_currentPipeline.computePipeline];
  [computeEncoder setBuffer:_resources.uniformBuffer
                     offset:bufferIndex * sizeof(Uniforms)
                    atIndex:0];

  MTLSize gridSize = MTLSizeMake(_particleConfig.count, 1, 1);
  NSUInteger maxThreads =
      _currentPipeline.computePipeline.maxTotalThreadsPerThreadgroup;
  NSUInteger threadGroupSizeX = 512; // Matches GROUP_SIZE in particles.metal
  if (threadGroupSizeX > maxThreads) {
    threadGroupSizeX = maxThreads;
  }
  MTLSize threadgroupSize = MTLSizeMake(threadGroupSizeX, 1, 1);

  [computeEncoder dispatchThreads:gridSize
            threadsPerThreadgroup:threadgroupSize];
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

- (void)setupDebugOverlay {
  NSLog(@"Setting up debug overlay...");
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *shaderPath = [bundle pathForResource:@"debug_overlay"
                                          ofType:@"metal"
                                     inDirectory:@"shaders"];

  if (!shaderPath) {
    // Fallback for local development
    shaderPath = @"shaders/system/debug_overlay.metal";
    NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
    shaderPath = [cwd stringByAppendingPathComponent:shaderPath];
  }

  if (![[NSFileManager defaultManager] fileExistsAtPath:shaderPath]) {
    NSLog(@"Debug overlay shader not found at: %@", shaderPath);
    return;
  }

  NSLog(@"Loading debug overlay shader from: %@", shaderPath);

  NSError *error = nil;
  NSLog(@"Compiling debug overlay shader...");
  ShaderCompilationResult *result =
      [[ShaderCompiler sharedCompiler] compileShaderFromPath:shaderPath
                                                      device:_device
                                                       error:&error];
  NSLog(@"Debug overlay shader compilation result: %@, error: %@", result,
        error);

  if (result.library) {
    id<MTLFunction> fragFunc =
        [result.library newFunctionWithName:@"debug_overlay_fragment"];

    if (fragFunc) {
      MTLRenderPipelineDescriptor *desc =
          [[MTLRenderPipelineDescriptor alloc] init];
      desc.vertexFunction = [self loadSystemShaderWithName:@"vertex_main"];
      desc.fragmentFunction = fragFunc;
      desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
      desc.colorAttachments[0].blendingEnabled = YES;
      desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
      desc.colorAttachments[0].destinationRGBBlendFactor =
          MTLBlendFactorOneMinusSourceAlpha;

      NSError *pError = nil;
      _resources.debugOverlayPipeline =
          [_device newRenderPipelineStateWithDescriptor:desc error:&pError];
    }
  }
}

- (void)renderDebugOverlayWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                 descriptor:
                                     (MTLRenderPassDescriptor *)descriptor
                                   uniforms:(Uniforms *)uniforms
                                bufferIndex:(NSUInteger)bufferIndex {
  if (!_showDebugOverlay || !_resources.debugOverlayPipeline)
    return;

  descriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;

  id<MTLRenderCommandEncoder> encoder =
      [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
  [encoder setRenderPipelineState:_resources.debugOverlayPipeline];
  [encoder setVertexBuffer:_resources.vertexBuffer offset:0 atIndex:0];
  [encoder setFragmentBuffer:_resources.uniformBuffer
                      offset:bufferIndex * sizeof(Uniforms)
                     atIndex:0];

  [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                      indexCount:6
                       indexType:MTLIndexTypeUInt16
                     indexBuffer:_resources.indexBuffer
               indexBufferOffset:0];
  [encoder endEncoding];
}

- (void)setParticleCount:(NSInteger)count {
  // Clamp to pre-allocated maximum (100k)
  _particleConfig.count = MIN(100000, MAX(0, count));
}

- (void)setParticleGravity:(float)gravity {
  _particleConfig.gravity = gravity;
}

#pragma mark - Audio

- (void)setAudioReactivityEnabled:(BOOL)enabled {
  _audioReactivityEnabled = enabled;
  if (enabled) {
    if (!_audioInput) {
      _audioInput = std::make_unique<ShaderCandy::Audio::AudioInput>();
      _audioInput->initialize(44100, 1024);
    }
    _audioInput->start();
  } else {
    if (_audioInput) {
      _audioInput->stop();
    }
  }
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
  // Metal debugger capture:
  // - Use MTLCaptureManager in Xcode for detailed GPU frame capture
  // - Or set environment variable METAL_DEVICE_DEBUG_FLAGS=capture_on_launch
  // This method reserved for potential future programmatic capture
  NSLog(@"MetalRenderer: GPU frame capture - use Xcode Metal Debugger");
#endif
}

@end
