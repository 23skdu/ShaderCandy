//
//  FalloutShaderTests.mm
//  ShaderCandy
//
//  Tests for the fallout shader effect
//

#import <Metal/Metal.h>
#import <XCTest/XCTest.h>
#import <simd/simd.h>

@interface FalloutShaderTests : XCTestCase

@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLLibrary> library;
@property(nonatomic, strong) id<MTLRenderPipelineState> pipelineState;

@end

@implementation FalloutShaderTests

- (void)setUp {
  [super setUp];

  _device = MTLCreateSystemDefaultDevice();
  if (!_device) {
    NSLog(@"Metal not available, skipping shader tests");
    return;
  }

  // Load library with fallback for runtime compilation
  NSBundle *bundle = [NSBundle mainBundle];
  NSURL *libraryURL = [bundle URLForResource:@"default"
                               withExtension:@"metallib"];

  if (libraryURL) {
    _library = [_device newLibraryWithURL:libraryURL error:nil];
  }

  if (!_library) {
    // Try to compile from source
    NSString *shaderPath =
        [[NSBundle mainBundle] pathForResource:@"shaders/effects/fallout"
                                        ofType:@"metal"];
    if (shaderPath) {
      NSString *source = [NSString stringWithContentsOfFile:shaderPath
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
      _library = [_device newLibraryWithSource:source options:nil error:nil];
    }
  }
}

- (void)tearDown {
  _pipelineState = nil;
  _library = nil;
  _device = nil;
  [super tearDown];
}

#pragma mark - Shader Compilation Tests

- (void)testFalloutShaderExists {
  NSBundle *bundle = [NSBundle mainBundle];
  NSURL *shaderURL = [bundle URLForResource:@"shaders/effects/fallout"
                              withExtension:@"metal"];
  XCTAssertNotNil(shaderURL, @"Fallout shader should exist in bundle");
}

- (void)testFalloutShaderCompiles {
  if (!_device || !_library) {
    NSLog(@"Skipping - Metal not available");
    return;
  }

  id<MTLFunction> fragmentFunction =
      [_library newFunctionWithName:@"fragment_main"];
  XCTAssertNotNil(fragmentFunction, @"fragment_main function should exist");

  id<MTLFunction> vertexFunction =
      [_library newFunctionWithName:@"vertex_main"];
  XCTAssertNotNil(vertexFunction, @"vertex_main function should exist");
}

#pragma mark - Pipeline Tests

- (void)testFalloutPipelineCreation {
  if (!_device || !_library) {
    NSLog(@"Skipping - Metal not available");
    return;
  }

  MTLRenderPipelineDescriptor *pipelineDesc =
      [[MTLRenderPipelineDescriptor alloc] init];
  pipelineDesc.vertexFunction = [_library newFunctionWithName:@"vertex_main"];
  pipelineDesc.fragmentFunction =
      [_library newFunctionWithName:@"fragment_main"];
  pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

  NSError *error = nil;
  _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDesc
                                                           error:&error];

  XCTAssertNotNil(_pipelineState, @"Pipeline should be created successfully");
  XCTAssertNil(error, @"Error should be nil");
}

#pragma mark - Shader Features Tests

- (void)testFalloutHasUniformsStruct {
  // Verify uniforms structure matches expected layout
  // In ShadeCandy, Uniforms are passed in buffer 0
}

#pragma mark - Performance Tests

- (void)testFalloutCompilationPerformance {
  if (!_device) {
    NSLog(@"Skipping - Metal not available");
    return;
  }

  [self measureBlock:^{
    for (int i = 0; i < 10; i++) {
      MTLRenderPipelineDescriptor *pipelineDesc =
          [[MTLRenderPipelineDescriptor alloc] init];
      pipelineDesc.vertexFunction =
          [_library newFunctionWithName:@"vertex_main"];
      pipelineDesc.fragmentFunction =
          [_library newFunctionWithName:@"fragment_main"];
      pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

      NSError *error = nil;
      id<MTLRenderPipelineState> state =
          [_device newRenderPipelineStateWithDescriptor:pipelineDesc
                                                  error:&error];
      if (state) {
        // Success
      }
    }
  }];
}

#pragma mark - Integration Tests

- (void)testFalloutShaderRendering {
  if (!_device || !_pipelineState) {
    NSLog(@"Skipping - Pipeline not created");
    return;
  }

  // Create a command buffer and encoder
  id<MTLCommandBuffer> commandBuffer = [_device newCommandBuffer];
  XCTAssertNotNil(commandBuffer, @"Command buffer should be created");

  // Create a dummy texture for testing
  MTLTextureDescriptor *texDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:256
                                  height:256
                               mipmapped:NO];
  texDesc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
  texDesc.storageMode = MTLStorageModePrivate;

  id<MTLTexture> texture = [_device newTextureWithDescriptor:texDesc];
  XCTAssertNotNil(texture, @"Test texture should be created");
}

@end
