//
//  ShaderCandyView.mm
//  ShaderCandy
//
//  macOS Screen Saver Implementation
//

#import "ShaderCandyView.h"
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#import "../../core/ShaderInterop.h"

@interface ShaderCandyView () {
  dispatch_semaphore_t _inFlightSemaphore;
}
@property(nonatomic, assign) BOOL isCycling;

// Transitions
@property(nonatomic, strong, nullable) id<MTLRenderPipelineState>
    previousPipelineState;
@property(nonatomic, assign) NSTimeInterval transitionStartTime;
@property(nonatomic, assign) NSTimeInterval transitionDuration;
@property(nonatomic, assign) BOOL isTransitioning;
@property(nonatomic, assign) NSTimeInterval cycleInterval;
@property(nonatomic, strong) NSDate *lastCycleTime;
@end

@implementation ShaderCandyView

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  self = [super initWithFrame:frame isPreview:isPreview];
  if (self) {
    NSLog(@"ShaderCandy: init with frame: %@", NSStringFromRect(frame));
    [self preInitialize];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    NSLog(@"ShaderCandy: init with coder");
    [self preInitialize];
  }
  return self;
}

// Initialization logic moved to end of file to support Shader Cycling

#pragma mark - Metal Setup

- (void)setupMetal {
  if (self.metalSetup)
    return;

  NSLog(@"ShaderCandy: Starting Metal setup (frame: %@)...",
        NSStringFromRect(self.bounds));

  if (NSWidth(self.bounds) < 1.0 || NSHeight(self.bounds) < 1.0) {
    NSLog(
        @"ShaderCandy: Frame is too small for Metal setup, skipping for now.");
    return;
  }

  // Get default Metal device
  self.device = MTLCreateSystemDefaultDevice();
  if (!self.device) {
    NSLog(@"ShaderCandy: Metal is not supported on this device");
    return;
  }
  NSLog(@"ShaderCandy: Metal device created: %@", self.device.name);

  // Create command queue
  self.commandQueue = [self.device newCommandQueue];

  // Create MTKView for rendering
  self.mtkView = [[MTKView alloc] initWithFrame:self.bounds device:self.device];
  self.mtkView.delegate = self;
  self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  self.mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
  self.mtkView.framebufferOnly = YES;
  self.mtkView.preferredFramesPerSecond = 60;
  self.mtkView.enableSetNeedsDisplay = NO;
  self.mtkView.paused = NO;
  self.mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  // Add MTKView as subview
  [self addSubview:self.mtkView];
  NSLog(@"ShaderCandy: MTKView added as subview to frame: %@",
        NSStringFromRect(self.bounds));

  // Create vertex buffer for fullscreen quad (4 vertices for indexed drawing)
  static const float vertices[] = {
      // Position (x, y)    // TexCoord (u, v)
      -1.0f, -1.0f, 0.0f, 0.0f, // Bottom-Left
      1.0f,  -1.0f, 1.0f, 0.0f, // Bottom-Right
      -1.0f, 1.0f,  0.0f, 1.0f, // Top-Left
      1.0f,  1.0f,  1.0f, 1.0f  // Top-Right
  };

  // Indices for two triangles forming a quad
  static const uint16_t indices[] = {
      0, 1, 2, // First Triangle
      2, 1, 3  // Second Triangle
  };

  self.vertexBuffer =
      [self.device newBufferWithBytes:vertices
                               length:sizeof(vertices)
                              options:MTLResourceStorageModeShared];

  self.indexBuffer =
      [self.device newBufferWithBytes:indices
                               length:sizeof(indices)
                              options:MTLResourceStorageModeShared];

  // Create uniform buffer (triple buffered for performance)
  self.uniformBuffer =
      [self.device newBufferWithLength:sizeof(Uniforms) * 3
                               options:MTLResourceStorageModeShared];

  // Initialize semaphore for triple buffering synchronization
  _inFlightSemaphore = dispatch_semaphore_create(3);

  // Setup Textures and Samplers
  [self setupTextures];
  [self setupBloomPipelines];
  [self setupParticles];
  self.metalSetup = YES;
}

- (void)setupParticles {
  self.numParticles = 10000;
  self.particleBuffer =
      [self.device newBufferWithLength:sizeof(Particle) * self.numParticles
                               options:MTLResourceStorageModeShared];

  Particle *p = (Particle *)self.particleBuffer.contents;
  for (int i = 0; i < self.numParticles; i++) {
    p[i].position = (vector_float2){(float)rand() / RAND_MAX * 2.0f - 1.0f,
                                    (float)rand() / RAND_MAX * 2.0f - 1.0f};
    p[i].velocity = (vector_float2){0, 0};
    p[i].life = (float)rand() / RAND_MAX;
    p[i].size = 1.0f + (float)rand() / RAND_MAX * 2.0f;
    p[i].color = (vector_float4){1, 1, 1, 1};
  }
}

- (void)setupTextures {
  CGSize size = self.mtkView.drawableSize;
  if (size.width <= 0 || size.height <= 0)
    size = self.frame.size;

  MTLTextureDescriptor *texDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                   width:size.width
                                  height:size.height
                               mipmapped:NO];
  texDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

  self.sceneTexture = [self.device newTextureWithDescriptor:texDesc];

  // Simulation textures (Fixed size for stability)
  MTLTextureDescriptor *simDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                   width:512
                                  height:512
                               mipmapped:NO];
  simDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  self.simulationTextureA = [self.device newTextureWithDescriptor:simDesc];
  self.simulationTextureB = [self.device newTextureWithDescriptor:simDesc];

  // Bloom textures are 1/2 size for performance
  texDesc.width /= 2;
  texDesc.height /= 2;
  self.bloomTextureA = [self.device newTextureWithDescriptor:texDesc];
  self.bloomTextureB = [self.device newTextureWithDescriptor:texDesc];

  MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
  samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
  samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
  samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
  samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
  self.samplerState = [self.device newSamplerStateWithDescriptor:samplerDesc];
}

- (void)setupBloomPipelines {
  NSError *error = nil;
  NSString *path = [self pathForShader:@"bloom"];
  if (!path)
    return;

  NSString *source = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  if (!source)
    return;

  // Inject interop header
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *interopPath = [bundle pathForResource:@"ShaderInterop"
                                           ofType:@"h"
                                      inDirectory:@"shaders"];
  NSString *interopHeader =
      [NSString stringWithContentsOfFile:interopPath
                                encoding:NSUTF8StringEncoding
                                   error:nil];

  NSString *fullSource = [NSString
      stringWithFormat:
          @"%@\n\nvertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n   "
          @" VertexOut out;\n    out.position = float4(in.position, 0.0, "
          @"1.0);\n    out.texCoord = in.texCoord;\n    return out;\n}\n\n%@",
          interopHeader ?: @"", source];

  id<MTLLibrary> bloomLib = [self.device newLibraryWithSource:fullSource
                                                      options:nil
                                                        error:&error];
  if (error) {
    NSLog(@"Bloom compile error: %@", error);
    return;
  }

  self.thresholdPipeline = [self createBloomPipeline:bloomLib
                                            fragment:@"bloom_threshold"];
  self.blurHPipeline = [self createBloomPipeline:bloomLib
                                        fragment:@"bloom_blur_h"];
  self.blurVPipeline = [self createBloomPipeline:bloomLib
                                        fragment:@"bloom_blur_v"];
  self.combinePipeline = [self createBloomPipeline:bloomLib
                                          fragment:@"bloom_combine"];
}

- (id<MTLRenderPipelineState>)createBloomPipeline:(id<MTLLibrary>)library
                                         fragment:(NSString *)name {
  MTLRenderPipelineDescriptor *desc =
      [[MTLRenderPipelineDescriptor alloc] init];
  desc.vertexFunction = [library newFunctionWithName:@"vertex_main"];
  desc.fragmentFunction = [library newFunctionWithName:name];
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

  return [self.device newRenderPipelineStateWithDescriptor:desc error:nil];
}

#pragma mark - Shader Management

- (void)discoverShaders {
  NSMutableArray *shaders = [NSMutableArray array];

  // Get built-in shaders from bundle
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *shadersPath = [bundle pathForResource:@"shaders" ofType:nil];

  if (shadersPath) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:shadersPath error:nil];

    for (NSString *file in contents) {
      if ([file hasSuffix:@".metal"] || [file hasSuffix:@".frag"]) {
        NSString *name = [file stringByDeletingPathExtension];
        // Skip utility shaders
        if ([name isEqualToString:@"common"] ||
            [name isEqualToString:@"utils"] ||
            [name isEqualToString:@"ShaderInterop"]) {
          continue;
        }
        [shaders addObject:name];
      }
    }
  }

  // Add default shaders
  if (shaders.count == 0) {
    [shaders addObjectsFromArray:@[
      @"nebula", @"raymarch", @"mandelbulb", @"default"
    ]];
  }

  self.availableShaders = [shaders copy];
  self.currentShaderName = shaders.firstObject ?: @"default";
}

- (void)loadShaders {
  if (self.pipelineState) {
    self.previousPipelineState = self.pipelineState;
    self.isTransitioning = YES;
    self.transitionStartTime = [NSDate timeIntervalSinceReferenceDate];
    self.transitionDuration = 2.0; // 2 second smooth cross-fade
  }

  NSError *error = nil;

  // Try to load from bundle
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *metallibPath = [bundle pathForResource:@"default"
                                            ofType:@"metallib"];

  if (metallibPath) {
    // Load pre-compiled metallib
    self.shaderLibrary = [self.device newLibraryWithFile:metallibPath
                                                   error:&error];
    if (error) {
      NSLog(@"Failed to load metallib: %@", error);
      [self loadDefaultShader];
      return;
    }
  } else {
    // Compile from source
    [self compileShadersFromSource];
  }

  // Create pipeline state
  [self createPipelineStateWithVertex:@"vertex_main" fragment:@"fragment_main"];
}

- (NSString *)pathForShader:(NSString *)name {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  return [bundle pathForResource:name ofType:@"metal" inDirectory:@"shaders"];
}

- (NSDate *)modificationDateForPath:(NSString *)path {
  if (!path)
    return nil;
  NSDictionary *attrs =
      [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
  return [attrs fileModificationDate];
}

- (void)compileShadersFromSource {
  NSError *error = nil;
  NSString *shaderSource = nil;

  // Load interop header content to inject
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *interopPath = [bundle pathForResource:@"ShaderInterop"
                                           ofType:@"h"
                                      inDirectory:@"shaders"];
  NSString *interopHeader = @"";
  if (interopPath) {
    interopHeader = [NSString stringWithContentsOfFile:interopPath
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
  } else {
    // Fallback: search in src/core (for dev)
    interopPath = [[bundle bundlePath]
        stringByDeletingLastPathComponent]; // .../ShaderCandy/build-make/
    interopPath = [interopPath
        stringByAppendingPathComponent:@"../../src/core/ShaderInterop.h"];
    interopHeader = [NSString stringWithContentsOfFile:interopPath
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
  }

  // Load utils helper content to inject
  NSString *utilsPath = [bundle pathForResource:@"utils"
                                         ofType:@"metal"
                                    inDirectory:@"shaders/base"];
  NSString *utilsHeader = @"";
  if (utilsPath) {
    utilsHeader = [NSString stringWithContentsOfFile:utilsPath
                                            encoding:NSUTF8StringEncoding
                                               error:nil];
  } else {
    // Fallback: search in shaders/base (for dev)
    utilsPath = [[bundle bundlePath] stringByDeletingLastPathComponent];
    utilsPath = [utilsPath
        stringByAppendingPathComponent:@"../../shaders/base/utils.metal"];
    utilsHeader = [NSString stringWithContentsOfFile:utilsPath
                                            encoding:NSUTF8StringEncoding
                                               error:nil];
  }

  // Try to load from file
  NSString *path = [self pathForShader:self.currentShaderName];
  if (path) {
    shaderSource = [NSString stringWithContentsOfFile:path
                                             encoding:NSUTF8StringEncoding
                                                error:&error];
    if (error) {
      NSLog(@"Failed to read shader source: %@", error);
    } else {
      self.lastShaderReloadTime = [self modificationDateForPath:path];
    }
  }

  // Fallback to default if load failed
  if (!shaderSource) {
    shaderSource = @(R"(
        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                     constant Uniforms &uniforms [[buffer(0)]]) {
            float2 uv = in.texCoord;
            float t = uniforms.time;
            
            float3 color = float3(
                0.5 + 0.5 * sin(t + uv.x * 3.14159),
                0.5 + 0.5 * sin(t + uv.y * 3.14159 + 2.0),
                0.5 + 0.5 * sin(t + length(uv - 0.5) * 6.0)
            );
            
            return float4(color, 1.0);
        }
    )");
  }

  // Prepend interop header and standard boilerplate
  NSString *fullSource = [NSString
      stringWithFormat:
          @"%@\n%@\n\nvertex VertexOut vertex_main(VertexIn in [[stage_in]]) "
          @"{\n    VertexOut out;\n    out.position = float4(in.position, 0.0, "
          @"1.0);\n    out.texCoord = in.texCoord;\n    return out;\n}\n\n%@",
          interopHeader ?: @"", utilsHeader ?: @"", shaderSource];

  self.shaderLibrary = [self.device newLibraryWithSource:fullSource
                                                 options:nil
                                                   error:&error];
  if (error) {
    NSLog(@"Failed to compile shader: %@", error);
  }
}

- (void)loadDefaultShader {
  [self compileShadersFromSource];
  [self createPipelineStateWithVertex:@"vertex_main" fragment:@"fragment_main"];
}

- (void)createPipelineStateWithVertex:(NSString *)vertexFunc
                             fragment:(NSString *)fragmentFunc {
  if (!self.shaderLibrary)
    return;

  id<MTLFunction> vertexFunction =
      [self.shaderLibrary newFunctionWithName:vertexFunc];
  id<MTLFunction> fragmentFunction =
      [self.shaderLibrary newFunctionWithName:fragmentFunc];

  if (!vertexFunction || !fragmentFunction) {
    NSLog(@"Failed to load shader functions");
    return;
  }

  MTLRenderPipelineDescriptor *descriptor =
      [[MTLRenderPipelineDescriptor alloc] init];
  descriptor.vertexFunction = vertexFunction;
  descriptor.fragmentFunction = fragmentFunction;
  descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

  // Enable alpha blending for transitions
  descriptor.colorAttachments[0].blendingEnabled = YES;
  descriptor.colorAttachments[0].sourceRGBBlendFactor =
      MTLBlendFactorSourceAlpha;
  descriptor.colorAttachments[0].sourceAlphaBlendFactor =
      MTLBlendFactorSourceAlpha;
  descriptor.colorAttachments[0].destinationRGBBlendFactor =
      MTLBlendFactorOneMinusSourceAlpha;
  descriptor.colorAttachments[0].destinationAlphaBlendFactor =
      MTLBlendFactorOneMinusSourceAlpha;

  // Create Vertex Descriptor
  MTLVertexDescriptor *vertexDescriptor =
      [MTLVertexDescriptor vertexDescriptor];

  // Position (Attribute 0)
  vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
  vertexDescriptor.attributes[0].offset = 0;
  vertexDescriptor.attributes[0].bufferIndex = 0;

  // TexCoord (Attribute 1)
  vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
  vertexDescriptor.attributes[1].offset = 2 * sizeof(float); // 8 bytes
  vertexDescriptor.attributes[1].bufferIndex = 0;

  // Layout
  vertexDescriptor.layouts[0].stride = 4 * sizeof(float); // 16 bytes
  vertexDescriptor.layouts[0].stepRate = 1;
  vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

  descriptor.vertexDescriptor = vertexDescriptor;

  NSError *error = nil;
  id<MTLRenderPipelineState> nextState =
      [self.device newRenderPipelineStateWithDescriptor:descriptor
                                                  error:&error];
  if (nextState) {
    self.pipelineState = nextState;
  } else {
    NSLog(@"Failed to create main pipeline state: %@", error);
  }

  // Handle Simulation Pipeline if exists
  id<MTLFunction> simFunction =
      [self.shaderLibrary newFunctionWithName:@"fragment_sim"];
  if (simFunction) {
    descriptor.fragmentFunction = simFunction;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    id<MTLRenderPipelineState> nextSim =
        [self.device newRenderPipelineStateWithDescriptor:descriptor error:nil];
    if (nextSim) {
      self.simulationPipeline = nextSim;
      self.needsSimulation = YES;
    }
  } else {
    self.simulationPipeline = (id<MTLRenderPipelineState>)nil;
    self.needsSimulation = NO;
  }

  // Handle Particle Pipelines
  id<MTLFunction> computeFunc =
      [self.shaderLibrary newFunctionWithName:@"compute_particles"];
  if (computeFunc) {
    NSError *cError = nil;
    id<MTLComputePipelineState> nextCompute =
        [self.device newComputePipelineStateWithFunction:computeFunc
                                                   error:&cError];
    if (nextCompute) {
      self.particleComputePipeline = nextCompute;

      id<MTLFunction> vFunc =
          [self.shaderLibrary newFunctionWithName:@"vertex_particles"];
      id<MTLFunction> fFunc =
          [self.shaderLibrary newFunctionWithName:@"fragment_particles"];

      if (vFunc && fFunc) {
        MTLRenderPipelineDescriptor *pDesc =
            [[MTLRenderPipelineDescriptor alloc] init];
        pDesc.vertexFunction = vFunc;
        pDesc.fragmentFunction = fFunc;
        pDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
        pDesc.colorAttachments[0].blendingEnabled = YES;
        pDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
        pDesc.colorAttachments[0].sourceRGBBlendFactor =
            MTLBlendFactorSourceAlpha;

        id<MTLRenderPipelineState> nextPartRender =
            [self.device newRenderPipelineStateWithDescriptor:pDesc error:nil];
        if (nextPartRender) {
          self.particleRenderPipeline = nextPartRender;
        }
      }
    }
  } else {
    self.particleComputePipeline = nil;
    self.particleRenderPipeline = nil;
  }
}

- (void)reloadShaders {
  if (!self.enableHotReload)
    return;

  // Check if shaders have been modified
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  if (now - self.lastShaderCheck < 1.0)
    return; // Check at most once per second

  self.lastShaderCheck = now;

  NSString *path = [self pathForShader:self.currentShaderName];
  if (!path)
    return;

  NSDate *modDate = [self modificationDateForPath:path];

  // Check if modified since last reload. Handle case where lastShaderReloadTime
  // is nil.
  if (modDate && self.lastShaderReloadTime &&
      ![modDate isEqualToDate:self.lastShaderReloadTime]) {
    NSLog(@"Detected shader change at path: %@", path);
    // Recompile
    [self compileShadersFromSource];
    [self createPipelineStateWithVertex:@"vertex_main"
                               fragment:@"fragment_main"];
  } else if (modDate && !self.lastShaderReloadTime) {
    // Initial load time set
    self.lastShaderReloadTime = modDate;
  }
}

#pragma mark - Rendering

- (void)drawRect:(NSRect)rect {
  // MTKView handles rendering via delegate
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  [self setupTextures];
}

- (void)drawInMTKView:(MTKView *)view {
  if (!self.pipelineState || !self.commandQueue)
    return;

  // Wait for a buffer to become available
  dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

  // Get current drawable and render pass descriptor
  id<CAMetalDrawable> drawable = view.currentDrawable;
  MTLRenderPassDescriptor *finalDescriptor = view.currentRenderPassDescriptor;

  if (!drawable || !finalDescriptor) {
    dispatch_semaphore_signal(_inFlightSemaphore);
    return;
  }

  // Update uniforms
  NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.startTime];
  NSUInteger bufferIndex = self.frameCount % 3;
  uint8_t *bufferPtr = (uint8_t *)[self.uniformBuffer contents];
  Uniforms *uniforms = (Uniforms *)(bufferPtr + bufferIndex * sizeof(Uniforms));

  uniforms->time = (float)elapsed;
  uniforms->resolution = (vector_float2){(float)view.drawableSize.width,
                                         (float)view.drawableSize.height};

  // Get mouse position
  NSPoint mouseLocation = [NSEvent mouseLocation];
  NSRect frame = [self.window
      convertRectFromScreen:NSMakeRect(mouseLocation.x, mouseLocation.y, 0, 0)];
  uniforms->mouse = (vector_float2){
      static_cast<float>(frame.origin.x / view.drawableSize.width),
      static_cast<float>(frame.origin.y / view.drawableSize.height)};

  // Set date
  NSDateComponents *components = [[NSCalendar currentCalendar]
      components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                 NSCalendarUnitHour | NSCalendarUnitMinute |
                 NSCalendarUnitSecond
        fromDate:[NSDate date]];
  uniforms->date = (vector_float4){
      (float)components.year, (float)components.month, (float)components.day,
      (float)(components.hour * 3600 + components.minute * 60 +
              components.second)};

  uniforms->speed = self.speed;
  uniforms->intensity = self.intensity;
  uniforms->gravity = self.gravity;
  uniforms->mouseButtons = (float)[NSEvent pressedMouseButtons];

  uniforms->frame = (int32_t)self.frameCount;
  uniforms->deltaTime = (float)self.animationTimeInterval;
  uniforms->alpha = 1.0; // Default

  // Handle Transition Alpha
  float transitionFactor = 1.0;
  if (self.isTransitioning) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    transitionFactor =
        (now - self.transitionStartTime) / self.transitionDuration;
    if (transitionFactor >= 1.0) {
      self.isTransitioning = NO;
      self.previousPipelineState = nil;
      transitionFactor = 1.0;
    }
  }

  if (!self.indexBuffer) {
    dispatch_semaphore_signal(_inFlightSemaphore);
    return;
  }

  id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
  __block dispatch_semaphore_t semaphore = _inFlightSemaphore;
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    dispatch_semaphore_signal(semaphore);
  }];

  // --- Simulation Pass (Stateful effects) ---
  if (self.needsSimulation && self.simulationPipeline) {
    // Ping-pong: A -> B, or B -> A based on frame parity
    id<MTLTexture> source = (self.frameCount % 2 == 0)
                                ? self.simulationTextureA
                                : self.simulationTextureB;
    id<MTLTexture> target = (self.frameCount % 2 == 0)
                                ? self.simulationTextureB
                                : self.simulationTextureA;

    MTLRenderPassDescriptor *simDesc =
        [MTLRenderPassDescriptor renderPassDescriptor];
    simDesc.colorAttachments[0].texture = target;
    simDesc.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    simDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> simEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:simDesc];
    [simEncoder setRenderPipelineState:self.simulationPipeline];
    [simEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    [simEncoder setFragmentBuffer:self.uniformBuffer
                           offset:bufferIndex * sizeof(Uniforms)
                          atIndex:0];
    [simEncoder setFragmentTexture:source atIndex:0]; // Previous state
    [simEncoder setFragmentSamplerState:self.samplerState atIndex:0];
    [simEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                           indexCount:6
                            indexType:MTLIndexTypeUInt16
                          indexBuffer:self.indexBuffer
                    indexBufferOffset:0];
    [simEncoder endEncoding];

    // Update uniforms for next pass if needed, but usually we just use 'target'
    // as input to scene
    self.sceneTexture =
        target; // Optimization: If simulation *is* the scene, or part of it
  }

  if (self.enableBloom && self.thresholdPipeline && self.sceneTexture) {
    // 1. Pass: Render main scene to offscreen texture
    MTLRenderPassDescriptor *sceneDesc =
        [MTLRenderPassDescriptor renderPassDescriptor];
    sceneDesc.colorAttachments[0].texture = self.sceneTexture;
    sceneDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    sceneDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    sceneDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

    id<MTLRenderCommandEncoder> sceneEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:sceneDesc];

    // If transitioning, we might need to render the PREVIOUS shader first
    if (self.isTransitioning && self.previousPipelineState) {
      uniforms->alpha = 1.0; // Draw previous background first
      [sceneEncoder setRenderPipelineState:self.previousPipelineState];
      [sceneEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
      [sceneEncoder setFragmentBuffer:self.uniformBuffer
                               offset:bufferIndex * sizeof(Uniforms)
                              atIndex:0];
      [sceneEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:6
                                indexType:MTLIndexTypeUInt16
                              indexBuffer:self.indexBuffer
                        indexBufferOffset:0];

      // Then draw new shader with transition alpha
      uniforms->alpha = transitionFactor;
      [sceneEncoder setRenderPipelineState:self.pipelineState];
      // Use setFragmentBytes to avoid race condition with the previous draw
      [sceneEncoder setFragmentBytes:uniforms
                              length:sizeof(Uniforms)
                             atIndex:0];
    } else {
      uniforms->alpha = 1.0;
      [sceneEncoder setRenderPipelineState:self.pipelineState];
      [sceneEncoder setFragmentBuffer:self.uniformBuffer
                               offset:bufferIndex * sizeof(Uniforms)
                              atIndex:0];
    }

    [sceneEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    // If RD, we might need simulation texture as input here
    if (self.needsSimulation) {
      id<MTLTexture> state = (self.frameCount % 2 == 0)
                                 ? self.simulationTextureB
                                 : self.simulationTextureA;
      [sceneEncoder setFragmentTexture:state atIndex:1];
    }
    [sceneEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                             indexCount:6
                              indexType:MTLIndexTypeUInt16
                            indexBuffer:self.indexBuffer
                      indexBufferOffset:0];
    [sceneEncoder endEncoding];

    // 2. Pass: Threshold (Isolate bright areas)
    MTLRenderPassDescriptor *bloomDesc =
        [MTLRenderPassDescriptor renderPassDescriptor];
    bloomDesc.colorAttachments[0].texture = self.bloomTextureA;
    bloomDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    bloomDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> threshEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:bloomDesc];
    [threshEncoder setRenderPipelineState:self.thresholdPipeline];
    [threshEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    [threshEncoder setFragmentTexture:self.sceneTexture atIndex:0];
    [threshEncoder setFragmentSamplerState:self.samplerState atIndex:0];
    [threshEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                              indexCount:6
                               indexType:MTLIndexTypeUInt16
                             indexBuffer:self.indexBuffer
                       indexBufferOffset:0];
    [threshEncoder endEncoding];

    // 3. Pass: Horizontal Blur (A -> B)
    bloomDesc.colorAttachments[0].texture = self.bloomTextureB;
    id<MTLRenderCommandEncoder> blurHEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:bloomDesc];
    [blurHEncoder setRenderPipelineState:self.blurHPipeline];
    [blurHEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    [blurHEncoder setFragmentTexture:self.bloomTextureA atIndex:0];
    [blurHEncoder setFragmentSamplerState:self.samplerState atIndex:0];
    [blurHEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                             indexCount:6
                              indexType:MTLIndexTypeUInt16
                            indexBuffer:self.indexBuffer
                      indexBufferOffset:0];
    [blurHEncoder endEncoding];

    // 4. Pass: Vertical Blur (B -> A)
    bloomDesc.colorAttachments[0].texture = self.bloomTextureA;
    id<MTLRenderCommandEncoder> blurVEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:bloomDesc];
    [blurVEncoder setRenderPipelineState:self.blurVPipeline];
    [blurVEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    [blurVEncoder setFragmentTexture:self.bloomTextureB atIndex:0];
    [blurVEncoder setFragmentSamplerState:self.samplerState atIndex:0];
    [blurVEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                             indexCount:6
                              indexType:MTLIndexTypeUInt16
                            indexBuffer:self.indexBuffer
                      indexBufferOffset:0];
    [blurVEncoder endEncoding];

    // 5. Final Pass: Combine scene and bloom to screen
    id<MTLRenderCommandEncoder> finalEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:finalDescriptor];
    [finalEncoder setRenderPipelineState:self.combinePipeline];
    [finalEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    [finalEncoder setFragmentTexture:self.sceneTexture atIndex:0];
    [finalEncoder setFragmentTexture:self.bloomTextureA atIndex:1];
    [finalEncoder setFragmentSamplerState:self.samplerState atIndex:0];
    [finalEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                             indexCount:6
                              indexType:MTLIndexTypeUInt16
                            indexBuffer:self.indexBuffer
                      indexBufferOffset:0];
    [finalEncoder endEncoding];
  } else {
    // Regular single pass rendering
    finalDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
    id<MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:finalDescriptor];

    if (self.isTransitioning && self.previousPipelineState) {
      uniforms->alpha = 1.0;
      [encoder setRenderPipelineState:self.previousPipelineState];
      [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
      [encoder setFragmentBuffer:self.uniformBuffer
                          offset:bufferIndex * sizeof(Uniforms)
                         atIndex:0];
      [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                          indexCount:6
                           indexType:MTLIndexTypeUInt16
                         indexBuffer:self.indexBuffer
                   indexBufferOffset:0];

      uniforms->alpha = transitionFactor;
      [encoder setRenderPipelineState:self.pipelineState];
      [encoder setFragmentBytes:uniforms length:sizeof(Uniforms) atIndex:0];
    } else {
      uniforms->alpha = 1.0;
      [encoder setRenderPipelineState:self.pipelineState];
      [encoder setFragmentBuffer:self.uniformBuffer
                          offset:bufferIndex * sizeof(Uniforms)
                         atIndex:0];
    }

    [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    // Pass simulation state if available
    if (self.needsSimulation) {
      id<MTLTexture> state = (self.frameCount % 2 == 0)
                                 ? self.simulationTextureB
                                 : self.simulationTextureA;
      [encoder setFragmentTexture:state atIndex:1];
    }
    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:6
                         indexType:MTLIndexTypeUInt16
                       indexBuffer:self.indexBuffer
                 indexBufferOffset:0];
    [encoder endEncoding];
  }

  // --- Particle Pass ---
  if (self.particleComputePipeline && self.particleRenderPipeline &&
      self.particleBuffer) {
    // 1. Update Particles (Compute)
    id<MTLComputeCommandEncoder> computeEncoder =
        [commandBuffer computeCommandEncoder];
    [computeEncoder setComputePipelineState:self.particleComputePipeline];
    [computeEncoder setBuffer:self.particleBuffer offset:0 atIndex:0];
    [computeEncoder setBuffer:self.uniformBuffer
                       offset:bufferIndex * sizeof(Uniforms)
                      atIndex:1];

    MTLSize gridSize = MTLSizeMake(self.numParticles, 1, 1);
    NSUInteger threadGroupSize =
        self.particleComputePipeline.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > self.numParticles)
      threadGroupSize = self.numParticles;
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);

    [computeEncoder dispatchThreads:gridSize
              threadsPerThreadgroup:threadgroupSize];
    [computeEncoder endEncoding];

    // 2. Render Particles (Over the scene)
    // We use the finalDescriptor but with LoadActionLoad to draw ON TOP
    finalDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    id<MTLRenderCommandEncoder> particleEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:finalDescriptor];
    [particleEncoder setRenderPipelineState:self.particleRenderPipeline];
    [particleEncoder setVertexBuffer:self.particleBuffer offset:0 atIndex:0];
    [particleEncoder drawPrimitives:MTLPrimitiveTypePoint
                        vertexStart:0
                        vertexCount:self.numParticles];
    [particleEncoder endEncoding];
  }

  [commandBuffer presentDrawable:drawable];
  [commandBuffer commit];
}

#pragma mark - Configuration

- (BOOL)hasConfigureSheet {
  return YES;
}

- (NSWindow *)configureSheet {
  if (self.configPanel) {
    return self.configPanel;
  }

  NSPanel *window = [[NSPanel alloc]
      initWithContentRect:NSMakeRect(0, 0, 320, 480)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setTitle:@"ShaderCandy Configuration"];

  // Set window properties for sandboxed sheets
  [window setLevel:NSFloatingWindowLevel];
  [window setHidesOnDeactivate:YES];
  self.configPanel = window;

  NSView *contentView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480)];
  [window setContentView:contentView];

  float y = 380;

  // Presets
  NSTextField *presetLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [presetLabel setStringValue:@"Preset:"];
  [presetLabel setBezeled:NO];
  [presetLabel setDrawsBackground:NO];
  [presetLabel setEditable:NO];
  [contentView addSubview:presetLabel];

  NSPopUpButton *presetPopup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(100, y - 2, 200, 25)
                                 pullsDown:NO];
  [presetPopup addItemsWithTitles:self.presets.allKeys];
  [presetPopup addItemWithTitle:@"Custom"];
  [presetPopup selectItemWithTitle:self.currentPresetName ?: @"Custom"];
  [presetPopup setTarget:self];
  [presetPopup setAction:@selector(presetChanged:)];
  [contentView addSubview:presetPopup];

  y -= 40;

  // Effect
  NSTextField *label =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [label setStringValue:@"Effect:"];
  [label setBezeled:NO];
  [label setDrawsBackground:NO];
  [label setEditable:NO];
  [contentView addSubview:label];

  NSPopUpButton *popup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(100, y - 2, 200, 25)
                                 pullsDown:NO];
  [popup addItemsWithTitles:self.availableShaders];
  [popup addItemWithTitle:@"Cycle All"];
  [popup setTarget:self];
  [popup setAction:@selector(shaderChanged:)];
  [contentView addSubview:popup];

  y -= 40;

  // FPS
  NSTextField *fpsLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [fpsLabel setStringValue:@"FPS:"];
  [fpsLabel setBezeled:NO];
  [fpsLabel setDrawsBackground:NO];
  [fpsLabel setEditable:NO];
  [contentView addSubview:fpsLabel];

  NSSegmentedControl *fpsControl = [NSSegmentedControl
      segmentedControlWithLabels:@[ @"30", @"60" ]
                    trackingMode:NSSegmentSwitchTrackingSelectOne
                          target:self
                          action:@selector(fpsChanged:)];
  [fpsControl setFrame:NSMakeRect(100, y - 2, 200, 25)];
  [contentView addSubview:fpsControl];

  y -= 40;

  // Speed
  NSTextField *speedLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [speedLabel setStringValue:@"Speed:"];
  [speedLabel setBezeled:NO];
  [speedLabel setDrawsBackground:NO];
  [speedLabel setEditable:NO];
  [contentView addSubview:speedLabel];

  NSSlider *speedSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  speedSlider.minValue = 0.1;
  speedSlider.maxValue = 3.0;
  speedSlider.floatValue = self.speed;
  speedSlider.target = self;
  speedSlider.action = @selector(speedChanged:);
  speedSlider.tag = 101; // Tag for easy lookup
  [contentView addSubview:speedSlider];

  y -= 30;

  // Intensity
  NSTextField *intLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [intLabel setStringValue:@"Intensity:"];
  [intLabel setBezeled:NO];
  [intLabel setDrawsBackground:NO];
  [intLabel setEditable:NO];
  [contentView addSubview:intLabel];

  NSSlider *intSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  intSlider.minValue = 0.0;
  intSlider.maxValue = 2.0;
  intSlider.floatValue = self.intensity;
  intSlider.target = self;
  intSlider.action = @selector(intensityChanged:);
  intSlider.tag = 102;
  [contentView addSubview:intSlider];

  y -= 30;

  // Gravity
  NSTextField *gravLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [gravLabel setStringValue:@"Gravity:"];
  [gravLabel setBezeled:NO];
  [gravLabel setDrawsBackground:NO];
  [gravLabel setEditable:NO];
  [contentView addSubview:gravLabel];

  NSSlider *gravSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  gravSlider.minValue = 0.1;
  gravSlider.maxValue = 5.0;
  gravSlider.floatValue = self.gravity;
  gravSlider.target = self;
  gravSlider.action = @selector(gravityChanged:);
  gravSlider.tag = 103;
  [contentView addSubview:gravSlider];

  y -= 40;

  // Bloom
  NSButton *bloomCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  [bloomCheck setButtonType:NSButtonTypeSwitch];
  [bloomCheck setTitle:@"Enable Bloom Glow"];
  [bloomCheck setState:self.enableBloom ? NSControlStateValueOn
                                        : NSControlStateValueOff];
  [bloomCheck setTarget:self];
  [bloomCheck setAction:@selector(bloomToggleChanged:)];
  bloomCheck.tag = 104;
  [contentView addSubview:bloomCheck];

  y -= 40;

  // OK
  NSButton *okButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(220, 20, 80, 24)];
  [okButton setTitle:@"OK"];
  [okButton setBezelStyle:NSBezelStyleRounded];
  [okButton setAction:@selector(closeConfig:)];
  [okButton setTarget:self];
  [contentView addSubview:okButton];

  // Load current selection UI state
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  NSString *current = [defaults stringForKey:@"selectedShader"];
  if (current)
    [popup selectItemWithTitle:current];
  else
    [popup selectItemWithTitle:@"Cycle All"];

  if ([defaults integerForKey:@"preferredFPS"] == 30)
    [fpsControl setSelectedSegment:0];
  else
    [fpsControl setSelectedSegment:1];

  return window;
}

- (void)presetChanged:(id)sender {
  NSString *name = [(NSPopUpButton *)sender titleOfSelectedItem];
  if ([name isEqualToString:@"Custom"])
    return;

  NSDictionary *p = self.presets[name];
  if (!p)
    return;

  self.currentPresetName = name;
  self.speed = [p[@"speed"] floatValue];
  self.intensity = [p[@"intensity"] floatValue];
  self.gravity = [p[@"gravity"] floatValue];
  self.enableBloom = [p[@"bloom"] boolValue];

  // Update defaults
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setObject:name forKey:@"currentPreset"];
  [defaults setFloat:self.speed forKey:@"speed"];
  [defaults setFloat:self.intensity forKey:@"intensity"];
  [defaults setFloat:self.gravity forKey:@"gravity"];
  [defaults setBool:self.enableBloom forKey:@"enableBloom"];
  [defaults synchronize];

  // Update UI if sheet is open
  NSWindow *sheet = [sender window];
  [(NSSlider *)[sheet.contentView viewWithTag:101] setFloatValue:self.speed];
  [(NSSlider *)[sheet.contentView viewWithTag:102]
      setFloatValue:self.intensity];
  [(NSSlider *)[sheet.contentView viewWithTag:103] setFloatValue:self.gravity];
  [(NSButton *)[sheet.contentView viewWithTag:104]
      setState:self.enableBloom ? NSControlStateValueOn
                                : NSControlStateValueOff];
}

- (void)speedChanged:(id)sender {
  self.speed = [(NSSlider *)sender floatValue];
  [[ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"]
      setFloat:self.speed
        forKey:@"speed"];
}

- (void)intensityChanged:(id)sender {
  self.intensity = [(NSSlider *)sender floatValue];
  [[ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"]
      setFloat:self.intensity
        forKey:@"intensity"];
}

- (void)gravityChanged:(id)sender {
  self.gravity = [(NSSlider *)sender floatValue];
  [[ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"]
      setFloat:self.gravity
        forKey:@"gravity"];
}

- (void)bloomToggleChanged:(id)sender {
  NSButton *check = (NSButton *)sender;
  self.enableBloom = (check.state == NSControlStateValueOn);

  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setBool:self.enableBloom forKey:@"enableBloom"];
  [defaults synchronize];
}

- (void)fpsChanged:(id)sender {
  NSSegmentedControl *control = (NSSegmentedControl *)sender;
  NSInteger fps = (control.selectedSegment == 0) ? 30 : 60;

  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setInteger:fps forKey:@"preferredFPS"];
  [defaults synchronize];

  self.preferredFPS = fps;
  self.animationTimeInterval = 1.0 / (double)fps;
}

- (void)shaderChanged:(id)sender {
  NSPopUpButton *popup = (NSPopUpButton *)sender;
  NSString *selected = [popup titleOfSelectedItem];

  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setObject:selected forKey:@"selectedShader"];
  [defaults synchronize];

  if (![selected isEqualToString:@"Cycle All"]) {
    self.currentShaderName = selected;
    [self loadShaders];
  }
}

- (void)startAnimation {
  NSLog(@"ShaderCandy: startAnimation with bounds: %@",
        NSStringFromRect(self.bounds));
  [super startAnimation];

  // macOS 15 / Tahoe Fix: Force initialization if frame is zero
  // Sometimes the system keeps zero bounds until startAnimation
  if (NSWidth(self.bounds) < 1.0) {
    NSLog(
        @"ShaderCandy: Bounds are zero in startAnimation, attempting to force "
        @"screen bounds...");
    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
    [self setFrame:screen.frame];
  }

  if (!self.isInitialized) {
    [self initialize];
  }
}

- (void)stopAnimation {
  NSLog(@"ShaderCandy: stopAnimation");
  [super stopAnimation];
}

- (void)setFrameSize:(NSSize)newSize {
  [super setFrameSize:newSize];
  NSLog(@"ShaderCandy: setFrameSize: %@", NSStringFromSize(newSize));
  if (self.mtkView) {
    self.mtkView.frame = self.bounds;
  }

  if (!self.isInitialized && newSize.width > 0) {
    [self initialize];
  }
}

- (void)setFrame:(NSRect)frame {
  [super setFrame:frame];
  NSLog(@"ShaderCandy: setFrame: %@", NSStringFromRect(frame));
  if (self.mtkView) {
    self.mtkView.frame = self.bounds;
  }

  if (!self.isInitialized && NSWidth(frame) > 0) {
    [self initialize];
  }
}

- (void)closeConfig:(id)sender {
  NSWindow *sheet = [sender window];
  NSWindow *parent = [sheet sheetParent];

  if (parent) {
    [parent endSheet:sheet returnCode:NSModalResponseOK];
  } else {
    [sheet close];
  }
}

- (void)preInitialize {
  // Initialize non-view timing and basic properties
  self.startTime = [NSDate date];
  self.frameCount = 0;
  self.enableHotReload = YES;
  self.lastShaderCheck = 0;
  self.isInitialized = NO;
  self.metalSetup = NO;

  // Set default frame rate
  self.animationTimeInterval = 1.0 / 60.0;

  // Start discover to have availableShaders ready
  [self discoverShaders];
}

#pragma mark - Shader Cycling

- (void)initialize {
  if (self.isInitialized)
    return;

  NSLog(@"ShaderCandy: Performing full initialization...");

  if (NSWidth(self.bounds) < 1.0 || NSHeight(self.bounds) < 1.0) {
    NSLog(@"ShaderCandy: Attempted initialize with invalid frame, deferring.");
    return;
  }

  // Initialize Presets
  self.presets = @{
    @"Cosmic" : @{
      @"speed" : @0.8,
      @"intensity" : @1.2,
      @"gravity" : @1.0,
      @"bloom" : @YES
    },
    @"Zen" : @{
      @"speed" : @0.3,
      @"intensity" : @0.5,
      @"gravity" : @0.5,
      @"bloom" : @NO
    },
    @"Chaos" : @{
      @"speed" : @2.0,
      @"intensity" : @1.8,
      @"gravity" : @3.0,
      @"bloom" : @YES
    },
    @"Vortex" : @{
      @"speed" : @0.5,
      @"intensity" : @1.0,
      @"gravity" : @5.0,
      @"bloom" : @YES
    }
  };

  // Load config
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults registerDefaults:@{
    @"selectedShader" : @"Cycle All",
    @"preferredFPS" : @60,
    @"enableBloom" : @YES,
    @"speed" : @1.0,
    @"intensity" : @1.0,
    @"gravity" : @1.0,
    @"currentPreset" : @"Cosmic"
  }];

  NSString *selected = [defaults stringForKey:@"selectedShader"];
  self.preferredFPS = [defaults integerForKey:@"preferredFPS"];
  self.enableBloom = [defaults boolForKey:@"enableBloom"];
  self.speed = [defaults floatForKey:@"speed"];
  self.intensity = [defaults floatForKey:@"intensity"];
  self.gravity = [defaults floatForKey:@"gravity"];
  self.currentPresetName = [defaults stringForKey:@"currentPreset"];

  // Set animation frame rate from config
  self.animationTimeInterval = 1.0 / (double)self.preferredFPS;

  if ([selected isEqualToString:@"Cycle All"]) {
    self.currentShaderName = self.availableShaders.firstObject;
    self.isCycling = YES;
    self.cycleInterval = 10.0; // 10 seconds per shader
    self.lastCycleTime = [NSDate date];
  } else {
    self.currentShaderName = selected;
    self.isCycling = NO;
  }

  // Setup Metal and Load Shaders
  [self setupMetal];
  [self loadShaders];

  self.isInitialized = YES;
  NSLog(@"ShaderCandy: Full initialization complete.");
}

- (void)animateOneFrame {
  // Increment frame counter
  self.frameCount++;

  // Check for shader reload
  if (self.enableHotReload && self.frameCount % 60 == 0) {
    [self reloadShaders];
  }

  // Handle Cycling
  if (self.isCycling) {
    NSTimeInterval elapsed =
        [[NSDate date] timeIntervalSinceDate:self.lastCycleTime];
    if (elapsed > self.cycleInterval) {
      [self cycleToNextShader];
    }
  }

  // Request redraw
  [self setNeedsDisplay:YES];
}

- (void)cycleToNextShader {
  NSUInteger index =
      [self.availableShaders indexOfObject:self.currentShaderName];
  if (index == NSNotFound) {
    index = 0;
  } else {
    index = (index + 1) % self.availableShaders.count;
  }

  self.currentShaderName = self.availableShaders[index];
  self.lastCycleTime = [NSDate date];
  [self loadShaders]; // Recompile/reload new shader
}
@end
