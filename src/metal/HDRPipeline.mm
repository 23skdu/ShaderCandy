//
//  HDRPipeline.mm
//  ShaderCandy
//
//  HDR rendering pipeline implementation
//

#import "HDRPipeline.h"
#import <AppKit/AppKit.h>

@interface HDRPipeline ()

@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong, nullable) id<MTLComputePipelineState> toneMapPipeline;
@property(nonatomic, strong, nullable) id<MTLLibrary> shaderLibrary;
@property(nonatomic, assign) BOOL isInitialized;
@property(nonatomic, assign) float currentHeadroom;

@end

@implementation HDRPipeline

+ (instancetype)sharedPipeline {
    static HDRPipeline *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[HDRPipeline alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _maxBrightness = 1000.0;
        _toneMapping = ToneMappingOperatorACES;
        _autoDetectHDR = YES;
        _hdrEnabled = NO;
        _edrEnabled = NO;
        _currentHeadroom = 1.0;
    }
    return self;
}

- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error {
    if (_isInitialized) return YES;
    
    _device = device;
    _commandQueue = [device newCommandQueue];
    
    // Check for HDR support
    if (_autoDetectHDR) {
        _hdrEnabled = [self detectHDRDisplay];
    }
    
    // Load tone mapping shaders
    NSError *shaderError = nil;
    _shaderLibrary = [device newDefaultLibrary];
    
    if (!_shaderLibrary) {
        // Create library from source if default not available
        NSString *shaderSource = [self toneMappingShaderSource];
        _shaderLibrary = [device newLibraryWithSource:shaderSource options:nil error:&shaderError];
    }
    
    if (!_shaderLibrary) {
        if (error) *error = shaderError;
        return NO;
    }
    
    // Create compute pipeline for tone mapping
    id<MTLFunction> toneMapFunction = [_shaderLibrary newFunctionWithName:@"toneMap"];
    if (toneMapFunction) {
        _toneMapPipeline = [device newComputePipelineStateWithFunction:toneMapFunction error:&shaderError];
    }
    
    _isInitialized = YES;
    return YES;
}

- (void)shutdown {
    _toneMapPipeline = nil;
    _shaderLibrary = nil;
    _commandQueue = nil;
    _device = nil;
    _isInitialized = NO;
}

- (MTLPixelFormat)hdrPixelFormat {
    return MTLPixelFormatRGBA16Float;
}

- (MTLPixelFormat)sdrPixelFormat {
    return MTLPixelFormatBGRA8Unorm;
}

- (id<MTLTexture>)createHDRTextureWithWidth:(NSUInteger)width height:(NSUInteger)height {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:[self hdrPixelFormat]
                                                                                      width:width
                                                                                     height:height
                                                                                  mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    desc.storageMode = MTLStorageModePrivate;
    
    return [_device newTextureWithDescriptor:desc];
}

- (id<MTLTexture>)createIntermediateTextureWithWidth:(NSUInteger)width height:(NSUInteger)height {
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                      width:width
                                                                                     height:height
                                                                                  mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    desc.storageMode = MTLStorageModePrivate;
    
    return [_device newTextureWithDescriptor:desc];
}

- (void)toneMapHDRTexture:(id<MTLTexture>)hdrTexture
                 toSDRTexture:(id<MTLTexture>)sdrTexture
                 commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    if (!_toneMapPipeline) return;
    
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder setComputePipelineState:_toneMapPipeline];
    [computeEncoder setTexture:hdrTexture atIndex:0];
    [computeEncoder setTexture:sdrTexture atIndex:1];
    
    // Set tone mapping parameters
    float params[4] = {_maxBrightness, (float)_toneMapping, _currentHeadroom, 0.0};
    [computeEncoder setBytes:params length:sizeof(params) atIndex:0];
    
    MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
    MTLSize threadGroups = MTLSizeMake(
        (hdrTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
        (hdrTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
        1
    );
    
    [computeEncoder dispatchThreadgroups:threadGroups threadsPerThreadgroup:threadGroupSize];
    [computeEncoder endEncoding];
}

- (void)renderWithEDR:(id<MTLTexture>)texture
        commandBuffer:(id<MTLCommandBuffer>)commandBuffer
            headroom:(float)headroom {
    _currentHeadroom = headroom;
    
    // Apply EDR headroom adjustment
    if (headroom > 1.0 && _edrEnabled) {
        // Brighten content to use EDR range
        // This would require a custom compute shader
    }
}

- (BOOL)detectHDRDisplay {
    // Check if main display supports HDR
    NSScreen *mainScreen = [NSScreen mainScreen];
    if (!mainScreen) return NO;
    
    // Check for EDR support (Extended Dynamic Range)
    NSNumber *edrAvailable = mainScreen.deviceDescription[@"NSScreenSupportsEDR"];
    if (edrAvailable && edrAvailable.boolValue) {
        _edrEnabled = YES;
        return YES;
    }
    
    // Check for HDR support on newer macOS
    if (@available(macOS 11.0, *)) {
        // Additional HDR checks would go here
    }
    
    return NO;
}

- (float)currentEDRHeadroom {
    if (!_edrEnabled) return 1.0;
    
    // Get current EDR headroom from screen
    NSScreen *mainScreen = [NSScreen mainScreen];
    if (!mainScreen) return 1.0;
    
    // Query maximum potential EDR headroom
    NSNumber *maxEdrValue = mainScreen.deviceDescription[@"NSScreenMaxEDR"];
    if (maxEdrValue) {
        return maxEdrValue.floatValue;
    }
    
    return 1.0;
}

- (NSData *)generateHDR10Metadata {
    // Create HDR10 metadata (SMPTE ST 2086)
    // This is a simplified version
    struct HDR10Metadata {
        uint16_t displayPrimaryRX;
        uint16_t displayPrimaryRY;
        uint16_t displayPrimaryGX;
        uint16_t displayPrimaryGY;
        uint16_t displayPrimaryBX;
        uint16_t displayPrimaryBY;
        uint16_t whitePointX;
        uint16_t whitePointY;
        uint16_t maxDisplayMasteringLuminance;
        uint16_t minDisplayMasteringLuminance;
        uint16_t maxContentLightLevel;
        uint16_t maxFrameAverageLightLevel;
    };
    
    struct HDR10Metadata metadata = {
        .displayPrimaryRX = 34000,  // D65 white point
        .displayPrimaryRY = 16000,
        .displayPrimaryGX = 13250,
        .displayPrimaryGY = 34500,
        .displayPrimaryBX = 7500,
        .displayPrimaryBY = 3000,
        .whitePointX = 15635,
        .whitePointY = 16450,
        .maxDisplayMasteringLuminance = (uint16_t)(_maxBrightness),
        .minDisplayMasteringLuminance = 0,
        .maxContentLightLevel = (uint16_t)(_maxBrightness),
        .maxFrameAverageLightLevel = (uint16_t)(_maxBrightness * 0.5)
    };
    
    return [NSData dataWithBytes:&metadata length:sizeof(metadata)];
}

- (NSString *)toneMappingShaderSource {
    return @"#include <metal_stdlib>\n"
            "using namespace metal;\n"
            "\n"
            "constant int TONE_MAP_ACES = 0;\n"
            "constant int TONE_MAP_REINHARD = 1;\n"
            "constant int TONE_MAP_FILMIC = 2;\n"
            "constant int TONE_MAP_HABLE = 3;\n"
            "\n"
            "float3 acesFilm(float3 x) {\n"
            "    float a = 2.51;\n"
            "    float b = 0.03;\n"
            "    float c = 2.43;\n"
            "    float d = 0.59;\n"
            "    float e = 0.14;\n"
            "    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);\n"
            "}\n"
            "\n"
            "float3 reinhard(float3 x) {\n"
            "    return x / (1.0 + x);\n"
            "}\n"
            "\n"
            "kernel void toneMap(\n"
            "    texture2d<float, access::read> hdrTexture [[texture(0)]],\n"
            "    texture2d<float, access::write> sdrTexture [[texture(1)]],\n"
            "    constant float4& params [[buffer(0)]],\n"
            "    uint2 gid [[thread_position_in_grid]]\n"
            ") {\n"
            "    if (gid.x >= hdrTexture.get_width() || gid.y >= hdrTexture.get_height()) return;\n"
            "    \n"
            "    float3 color = hdrTexture.read(gid).rgb;\n"
            "    int operatorType = int(params.y);\n"
            "    \n"
            "    if (operatorType == TONE_MAP_ACES) {\n"
            "        color = acesFilm(color);\n"
            "    } else if (operatorType == TONE_MAP_REINHARD) {\n"
            "        color = reinhard(color);\n"
            "    }\n"
            "    \n"
            "    sdrTexture.write(float4(color, 1.0), gid);\n"
            "}\n";
}

@end
