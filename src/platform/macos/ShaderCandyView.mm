//
//  ShaderCandyView.mm
//  ShaderCandy
//
//  macOS Screen Saver Implementation
//

#import "ShaderCandyView.h"
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

// Uniform structure matching shader
struct Uniforms {
    float time;
    vector_float2 resolution;
    vector_float2 mouse;
    vector_float4 date;
    int32_t frame;
    float deltaTime;
    vector_float2 padding;
};

@implementation ShaderCandyView

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self initialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    // Initialize timing
    self.startTime = [NSDate date];
    self.frameCount = 0;
    self.enableHotReload = YES;
    self.lastShaderCheck = 0;
    
    // Set animation frame rate
    self.animationTimeInterval = 1.0 / 60.0;
    
    // Setup Metal
    [self setupMetal];
    
    // Load available shaders
    [self discoverShaders];
    
    // Load initial shader
    [self loadShaders];
}

#pragma mark - Metal Setup

- (void)setupMetal {
    // Get default Metal device
    self.device = MTLCreateSystemDefaultDevice();
    if (!self.device) {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    
    // Create command queue
    self.commandQueue = [self.device newCommandQueue];
    
    // Create MTKView for rendering
    self.mtkView = [[MTKView alloc] initWithFrame:self.frame device:self.device];
    self.mtkView.delegate = self;
    self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
    self.mtkView.framebufferOnly = YES;
    self.mtkView.preferredFramesPerSecond = 60;
    self.mtkView.enableSetNeedsDisplay = NO;
    self.mtkView.paused = NO;
    
    // Add MTKView as subview
    [self addSubview:self.mtkView];
    
    // Create vertex buffer for fullscreen quad
    static const float vertices[] = {
        // Position (x, y)    // TexCoord (u, v)
        -1.0f, -1.0f,         0.0f, 0.0f,
         1.0f, -1.0f,         1.0f, 0.0f,
        -1.0f,  1.0f,         0.0f, 1.0f,
        -1.0f,  1.0f,         0.0f, 1.0f,
         1.0f, -1.0f,         1.0f, 0.0f,
         1.0f,  1.0f,         1.0f, 1.0f
    };
    
    self.vertexBuffer = [self.device newBufferWithBytes:vertices
                                                  length:sizeof(vertices)
                                                 options:MTLResourceStorageModeShared];
    
    // Create uniform buffer (triple buffered for performance)
    self.uniformBuffer = [self.device newBufferWithLength:sizeof(Uniforms) * 3
                                                  options:MTLResourceStorageModeShared];
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
            if ([file hasSuffix:@".metal"]) {
                NSString *name = [file stringByDeletingPathExtension];
                [shaders addObject:name];
            }
        }
    }
    
    // Add default shaders
    if (shaders.count == 0) {
        [shaders addObjectsFromArray:@[@"nebula", @"raymarch", @"mandelbulb", @"default"]];
    }
    
    self.availableShaders = [shaders copy];
    self.currentShaderName = shaders.firstObject ?: @"default";
}

- (void)loadShaders {
    NSError *error = nil;
    
    // Try to load from bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *metallibPath = [bundle pathForResource:@"default" ofType:@"metallib"];
    
    if (metallibPath) {
        // Load pre-compiled metallib
        self.shaderLibrary = [self.device newLibraryWithFile:metallibPath error:&error];
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

- (void)compileShadersFromSource {
    NSError *error = nil;
    
    // Default shader source
    NSString *shaderSource = @"
        #include <metal_stdlib>
        using namespace metal;
        
        struct Uniforms {
            float time;
            float2 resolution;
            float2 mouse;
            float4 date;
            int frame;
            float deltaTime;
            float2 padding;
        };
        
        struct VertexIn {
            float2 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
        };
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            out.texCoord = in.texCoord;
            return out;
        }
        
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
    ";
    
    self.shaderLibrary = [self.device newLibraryWithSource:shaderSource
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
    if (!self.shaderLibrary) return;
    
    id<MTLFunction> vertexFunction = [self.shaderLibrary newFunctionWithName:vertexFunc];
    id<MTLFunction> fragmentFunction = [self.shaderLibrary newFunctionWithName:fragmentFunc];
    
    if (!vertexFunction || !fragmentFunction) {
        NSLog(@"Failed to load shader functions");
        return;
    }
    
    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;
    descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    NSError *error = nil;
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:descriptor
                                                                      error:&error];
    if (error) {
        NSLog(@"Failed to create pipeline state: %@", error);
    }
}

- (void)reloadShaders {
    if (!self.enableHotReload) return;
    
    // Check if shaders have been modified
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - self.lastShaderCheck < 1.0) return; // Check at most once per second
    
    self.lastShaderCheck = now;
    
    // TODO: Check file modification times and reload if changed
    // For now, just recompile from source
    [self compileShadersFromSource];
    [self createPipelineStateWithVertex:@"vertex_main" fragment:@"fragment_main"];
}

#pragma mark - Rendering

- (void)drawRect:(NSRect)rect {
    // MTKView handles rendering via delegate
}

- (void)animateOneFrame {
    // Increment frame counter
    self.frameCount++;
    
    // Check for shader reload
    if (self.enableHotReload && self.frameCount % 60 == 0) {
        [self reloadShaders];
    }
    
    // Request redraw
    [self setNeedsDisplay:YES];
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Handle resize
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState || !self.commandQueue) return;
    
    // Get current drawable and render pass descriptor
    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor *descriptor = view.currentRenderPassDescriptor;
    
    if (!drawable || !descriptor) return;
    
    // Update uniforms
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.startTime];
    NSUInteger bufferIndex = self.frameCount % 3;
    uint8_t *bufferPtr = (uint8_t *)[self.uniformBuffer contents];
    Uniforms *uniforms = (Uniforms *)(bufferPtr + bufferIndex * sizeof(Uniforms));
    
    uniforms->time = (float)elapsed;
    uniforms->resolution = (vector_float2){(float)view.drawableSize.width, 
                                            (float)view.drawableSize.height};
    
    // Get mouse position if available
    NSPoint mouseLocation = [NSEvent mouseLocation];
    NSRect frame = [self.window convertRectFromScreen:NSMakeRect(mouseLocation.x, mouseLocation.y, 0, 0)];
    uniforms->mouse = (vector_float2){(float)frame.origin.x / view.drawableSize.width,
                                       (float)frame.origin.y / view.drawableSize.height};
    
    // Set date
    NSDateComponents *components = [[NSCalendar currentCalendar] 
        components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                 NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
        fromDate:[NSDate date]];
    uniforms->date = (vector_float4){(float)components.year, (float)components.month,
                                      (float)components.day, 
                                      (float)(components.hour * 3600 + components.minute * 60 + components.second)};
    
    uniforms->frame = (int32_t)self.frameCount;
    uniforms->deltaTime = (float)self.animationTimeInterval;
    
    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    // Create render encoder
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    
    // Set pipeline state
    [encoder setRenderPipelineState:self.pipelineState];
    
    // Set vertex buffer
    [encoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
    
    // Set fragment buffer
    [encoder setFragmentBuffer:self.uniformBuffer 
                        offset:bufferIndex * sizeof(Uniforms) 
                       atIndex:0];
    
    // Draw fullscreen quad
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle 
                vertexStart:0 
                vertexCount:6];
    
    [encoder endEncoding];
    
    // Present drawable
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

#pragma mark - Configuration

- (BOOL)hasConfigureSheet {
    return YES;
}

- (NSWindow *)configureSheet {
    // Create simple configuration window
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"ShaderCandy Configuration";
    alert.informativeText = @"Select shader effect:";
    
    // Add shader selection popup
    // This is simplified - in production, use a proper preferences window
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    return [alert window];
}

@end
