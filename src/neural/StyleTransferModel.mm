//
//  StyleTransferModel.mm
//  ShaderCandy
//
//  Individual style transfer model implementation
//

#import "StyleTransferModel.h"
#import <CoreVideo/CoreVideo.h>

@interface StyleTransferModel ()

@property(nonatomic, copy) NSString *styleName;
@property(nonatomic, copy) NSString *displayName;
@property(nonatomic, copy) NSString *category;
@property(nonatomic, copy, nullable) NSString *modelDescription;
@property(nonatomic, strong, nullable) NSImage *previewImage;
@property(nonatomic, strong, nullable) NSURL *modelURL;
@property(nonatomic, strong, nullable) MLModel *model;
@property(nonatomic, assign) CGSize inputSize;
@property(nonatomic, assign) float recommendedStrength;
@property(nonatomic, assign) BOOL isLoaded;
@property(nonatomic, strong, nullable) id<MTLDevice> metalDevice;

@end

@implementation StyleTransferModel

- (instancetype)initWithName:(NSString *)name modelURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _styleName = name;
        _modelURL = url;
        _displayName = name;
        _category = @"Custom";
        _inputSize = CGSizeMake(512, 512);
        _recommendedStrength = 0.8;
        _isLoaded = NO;
    }
    return self;
}

- (instancetype)initWithBundleStyle:(NSString *)styleName {
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *modelURL = [bundle URLForResource:styleName withExtension:@"mlmodelc" subdirectory:@"Styles"];

    self = [self initWithName:styleName modelURL:modelURL];
    if (self) {
        [self loadMetadataForStyle:styleName];
    }
    return self;
}

- (void)loadMetadataForStyle:(NSString *)styleName {
    NSDictionary *styleMetadata = @{
        @"starry_night": @{@"display": @"Starry Night", @"category": @"Art", @"strength": @(0.9)},
        @"monet": @{@"display": @"Monet", @"category": @"Art", @"strength": @(0.8)},
        @"picasso": @{@"display": @"Picasso", @"category": @"Art", @"strength": @(0.85)},
        @"hokusai": @{@"display": @"Great Wave", @"category": @"Art", @"strength": @(0.8)},
        @"mondrian": @{@"display": @"Mondrian", @"category": @"Abstract", @"strength": @(0.9)},
        @"cyberpunk": @{@"display": @"Cyberpunk", @"category": @"Modern", @"strength": @(0.85)},
        @"oil_painting": @{@"display": @"Oil Painting", @"category": @"Art", @"strength": @(0.75)},
        @"watercolor": @{@"display": @"Watercolor", @"category": @"Art", @"strength": @(0.8)},
        @"sketch": @{@"display": @"Pencil Sketch", @"category": @"Art", @"strength": @(0.85)},
        @"vintage": @{@"display": @"Vintage Film", @"category": @"Photo", @"strength": @(0.7)}
    };

    NSDictionary *metadata = styleMetadata[styleName];
    if (metadata) {
        _displayName = metadata[@"display"];
        _category = metadata[@"category"];
        _recommendedStrength = [metadata[@"strength"] floatValue];
    }
}

- (BOOL)loadWithError:(NSError **)error {
    if (_isLoaded) return YES;
    if (!_modelURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"StyleTransferModel" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"No model URL"}];
        }
        return NO;
    }

    MLModelConfiguration *config = [[MLModelConfiguration alloc] init];
    config.computeUnits = MLComputeUnitsAll;
    config.allowLowPrecisionAccumulationOnGPU = YES;

    NSError *loadError = nil;
    _model = [MLModel modelWithContentsOfURL:_modelURL configuration:config error:&loadError];

    if (!_model) {
        if (error) *error = loadError;
        return NO;
    }

    _isLoaded = YES;
    return YES;
}

- (void)unload {
    _model = nil;
    _isLoaded = NO;
}

- (nullable id<MTLTexture>)transferStyle:(id<MTLTexture>)inputTexture
                          commandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                 strength:(float)strength {
    if (!_isLoaded || !_model) return nil;

    @try {
        // Convert Metal texture to CVPixelBuffer
        CVPixelBufferRef inputBuffer = [self pixelBufferFromTexture:inputTexture];
        if (!inputBuffer) return nil;

        // Create input feature
        MLFeatureValue *inputFeature = [MLFeatureValue featureValueWithPixelBuffer:inputBuffer];
        NSDictionary *inputDict = @{@"image": inputFeature};
        NSError *providerError = nil;
        MLDictionaryFeatureProvider *inputProvider = [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&providerError];

        CVPixelBufferRelease(inputBuffer);

        if (!inputProvider) return nil;

        // Run prediction
        MLPredictionOptions *options = [[MLPredictionOptions alloc] init];
        NSError *predictionError = nil;
        id<MLFeatureProvider> outputProvider = [_model predictionFromFeatures:inputProvider options:options error:&predictionError];

        if (!outputProvider) return nil;

        // Extract output
        MLFeatureValue *outputFeature = [outputProvider featureValueForName:@"stylizedImage"];
        CVPixelBufferRef outputBuffer = outputFeature.imageBufferValue;

        if (!outputBuffer) return nil;

        // Convert back to Metal texture
        id<MTLTexture> outputTexture = [self textureFromPixelBuffer:outputBuffer commandBuffer:commandBuffer];

        // Apply strength blending if needed
        if (strength < 1.0 && outputTexture) {
            outputTexture = [self blendTexture:inputTexture withOutput:outputTexture strength:strength commandBuffer:commandBuffer];
        }

        return outputTexture;

    } @catch (NSException *exception) {
        NSLog(@"Style transfer failed for %@: %@", _styleName, exception);
        return nil;
    }
}

- (CVPixelBufferRef)pixelBufferFromTexture:(id<MTLTexture>)texture {
    NSDictionary *attributes = @{
        (NSString *)kCVPixelBufferMetalCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES
    };

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          texture.width,
                                          texture.height,
                                          kCVPixelFormatType_32BGRA,
                                          (__bridge CFDictionaryRef)attributes,
                                          &pixelBuffer);

    if (status != kCVReturnSuccess) return NULL;

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);

    [texture getBytes:pixelData
          bytesPerRow:CVPixelBufferGetBytesPerRow(pixelBuffer)
           fromRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
          mipmapLevel:0];

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBuffer;
}

- (id<MTLTexture>)textureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                      width:width
                                                                                     height:height
                                                                                  mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;

    id<MTLTexture> texture = [commandBuffer.device newTextureWithDescriptor:desc];

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);

    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
               mipmapLevel:0
                 withBytes:pixelData
               bytesPerRow:CVPixelBufferGetBytesPerRow(pixelBuffer)];

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    return texture;
}

- (id<MTLTexture>)blendTexture:(id<MTLTexture>)original withOutput:(id<MTLTexture>)output strength:(float)strength commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    // For now, return the stylized output
    // Full implementation would use a compute shader to blend
    if (strength >= 1.0) return output;
    if (strength <= 0.0) return original;

    // Return the styled texture (simplified)
    return output;
}

- (void)generatePreviewIfNeeded {
    if (_previewImage) return;

    // Generate preview using default image
    // This would run the model on a sample image
}

- (NSString *)description {
    return _modelDescription;
}

@end
