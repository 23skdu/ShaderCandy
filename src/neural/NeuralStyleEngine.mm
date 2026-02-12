//
//  NeuralStyleEngine.mm
//  ShaderCandy
//
//  CoreML neural style transfer implementation
//

#import "NeuralStyleEngine.h"
#import <CoreVideo/CoreVideo.h>

@interface NeuralStyleEngine ()

@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong, nullable) MLModel *currentModel;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *styleModels;
@property(nonatomic, assign) BOOL isInitialized;

@end

@implementation NeuralStyleEngine

+ (instancetype)sharedEngine {
    static NeuralStyleEngine *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[NeuralStyleEngine alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _styleStrength = 0.8;
        _styleModels = [NSMutableDictionary dictionary];
        _isInitialized = NO;
        [self discoverBundledStyles];
    }
    return self;
}

- (void)discoverBundledStyles {
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *modelURLs = [bundle URLsForResourcesWithExtension:@"mlmodelc" subdirectory:@"Styles"];
    
    for (NSURL *url in modelURLs) {
        NSString *styleName = url.lastPathComponent.stringByDeletingPathExtension;
        _styleModels[styleName] = url;
    }
    
    // Default styles if no bundled models
    if (_styleModels.count == 0) {
        NSArray *defaultStyles = @[@"starry_night", @"monet", @"picasso", @"hokusai", 
                                   @"mondrian", @"cyberpunk", @"oil_painting", @"watercolor"];
        for (NSString *style in defaultStyles) {
            _styleModels[style] = nil;
        }
    }
}

- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error {
    if (_isInitialized) return YES;
    
    _device = device;
    _commandQueue = [device newCommandQueue];
    
    if (!_commandQueue) {
        if (error) {
            *error = [NSError errorWithDomain:@"NeuralStyleEngine"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create command queue"}];
        }
        return NO;
    }
    
    _isInitialized = YES;
    return YES;
}

- (void)shutdown {
    [self unloadCurrentModel];
    _commandQueue = nil;
    _device = nil;
    _isInitialized = NO;
}

- (BOOL)loadModelAtPath:(NSURL *)modelURL error:(NSError **)error {
    if (!_isInitialized) {
        if (error) {
            *error = [NSError errorWithDomain:@"NeuralStyleEngine"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Engine not initialized"}];
        }
        return NO;
    }
    
    // Load CoreML model
    NSURL *compiledURL = modelURL;
    
    // Check if we need to compile
    if ([modelURL.pathExtension isEqualToString:@"mlmodel"]) {
        compiledURL = [MLModel compileModelAtURL:modelURL error:error];
        if (!compiledURL) return NO;
    }
    
    MLModelConfiguration *config = [[MLModelConfiguration alloc] init];
    config.computeUnits = MLComputeUnitsAll;
    config.allowLowPrecisionAccumulationOnGPU = YES;
    
    _currentModel = [MLModel modelWithContentsOfURL:compiledURL configuration:config error:error];
    
    return _currentModel != nil;
}

- (BOOL)loadStyleNamed:(NSString *)styleName error:(NSError **)error {
    NSURL *modelURL = _styleModels[styleName];
    if (!modelURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"NeuralStyleEngine"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Style '%@' not found", styleName]}];
        }
        return NO;
    }
    
    return [self loadModelAtPath:modelURL error:error];
}

- (nullable id<MTLTexture>)applyStyle:(id<MTLTexture>)inputTexture
                        commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    return [self applyStyle:inputTexture commandBuffer:commandBuffer strength:_styleStrength];
}

- (nullable id<MTLTexture>)applyStyle:(id<MTLTexture>)inputTexture
                        commandBuffer:(id<MTLCommandBuffer>)commandBuffer
                               strength:(float)strength {
    if (!_currentModel || !inputTexture) return nil;
    
    @try {
        // Create pixel buffer from Metal texture
        CVPixelBufferRef inputPixelBuffer = [self createPixelBufferFromTexture:inputTexture];
        if (!inputPixelBuffer) return nil;
        
        // Create ML feature provider
        MLFeatureValue *imageFeature = [MLFeatureValue featureValueWithPixelBuffer:inputPixelBuffer];
        NSDictionary *inputDict = @{@"image": imageFeature};
        NSError *providerError = nil;
        MLDictionaryFeatureProvider *inputProvider = [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&providerError];
        
        // Run inference
        MLPredictionOptions *predOptions = [[MLPredictionOptions alloc] init];
        NSError *predError = nil;
        id<MLFeatureProvider> outputProvider = [_currentModel predictionFromFeatures:inputProvider options:predOptions error:&predError];
        
        CVPixelBufferRelease(inputPixelBuffer);
        
        if (!outputProvider) return nil;
        
        // Get output pixel buffer
        MLFeatureValue *outputFeature = [outputProvider featureValueForName:@"stylizedImage"];
        CVPixelBufferRef outputPixelBuffer = outputFeature.imageBufferValue;
        
        if (!outputPixelBuffer) return nil;
        
        // Convert back to Metal texture
        id<MTLTexture> outputTexture = [self createTextureFromPixelBuffer:outputPixelBuffer commandBuffer:commandBuffer];
        
        // Blend with original based on strength
        if (strength < 1.0 && outputTexture) {
            outputTexture = [self blendTexture:inputTexture withStyledTexture:outputTexture strength:strength commandBuffer:commandBuffer];
        }
        
        return outputTexture;
        
    } @catch (NSException *exception) {
        NSLog(@"Style transfer failed: %@", exception);
        return nil;
    }
}

- (CVPixelBufferRef)createPixelBufferFromTexture:(id<MTLTexture>)texture {
    NSDictionary *pixelBufferAttributes = @{
        (NSString *)kCVPixelBufferMetalCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES
    };
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          texture.width,
                                          texture.height,
                                          kCVPixelFormatType_32BGRA,
                                          (__bridge CFDictionaryRef)pixelBufferAttributes,
                                          &pixelBuffer);
    
    if (status != kCVReturnSuccess) return NULL;
    
    // Copy texture data to pixel buffer
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    // Use blit command encoder to copy
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    
    MTLSize sourceSize = MTLSizeMake(texture.width, texture.height, 1);
    [blitEncoder copyFromTexture:texture
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:sourceSize
                       toBuffer:[_device newBufferWithBytesNoCopy:pixelData
                                                           length:texture.width * texture.height * 4
                                                          options:MTLResourceStorageModeShared
                                                      deallocator:nil]
                destinationOffset:0
           destinationBytesPerRow:texture.width * 4
         destinationBytesPerImage:texture.width * texture.height * 4];
    
    [blitEncoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (id<MTLTexture>)createTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                      width:width
                                                                                     height:height
                                                                                  mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    
    id<MTLTexture> texture = [_device newTextureWithDescriptor:desc];
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
               mipmapLevel:0
                 withBytes:pixelData
               bytesPerRow:CVPixelBufferGetBytesPerRow(pixelBuffer)];
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    return texture;
}

- (id<MTLTexture>)blendTexture:(id<MTLTexture>)original 
             withStyledTexture:(id<MTLTexture>)styled 
                       strength:(float)strength 
                  commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    // Simple blend - return styled if strength is 1.0, original if 0.0
    if (strength <= 0.0) return original;
    if (strength >= 1.0) return styled;
    
    // For intermediate values, we'd need a custom blend shader
    // For now, return the styled texture
    return styled;
}

- (void)prewarmModel {
    if (!_currentModel) return;
    
    // Run a dummy prediction to warm up the model
    @try {
        CVPixelBufferRef dummyBuffer = NULL;
        NSDictionary *attributes = @{(NSString *)kCVPixelBufferMetalCompatibilityKey: @YES};
        CVPixelBufferCreate(kCFAllocatorDefault, 256, 256, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attributes, &dummyBuffer);
        
        if (dummyBuffer) {
            MLFeatureValue *feature = [MLFeatureValue featureValueWithPixelBuffer:dummyBuffer];
            NSDictionary *inputDict = @{@"image": feature};
            NSError *error = nil;
            MLDictionaryFeatureProvider *input = [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&error];
            if (input) {
                MLPredictionOptions *options = [[MLPredictionOptions alloc] init];
                [_currentModel predictionFromFeatures:input options:options error:&error];
            }
            CVPixelBufferRelease(dummyBuffer);
        }
    } @catch (NSException *exception) {
        // Ignore prewarm errors
    }
}

- (void)unloadCurrentModel {
    _currentModel = nil;
}

- (NSArray<NSString *> *)availableStyles {
    return [_styleModels.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

@end
