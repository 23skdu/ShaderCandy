//
//  HDRPipeline.h
//  ShaderCandy
//
//  HDR rendering pipeline with 10-bit color support
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

typedef NS_ENUM(NSInteger, ToneMappingOperator) {
    ToneMappingOperatorACES,
    ToneMappingOperatorReinhard,
    ToneMappingOperatorFilmic,
    ToneMappingOperatorHable
};

@interface HDRPipeline : NSObject

@property(nonatomic, strong, readonly, nullable) id<MTLDevice> device;
@property(nonatomic, assign, readonly) BOOL hdrEnabled;
@property(nonatomic, assign, readonly) BOOL edrEnabled;
@property(nonatomic, assign) float maxBrightness;
@property(nonatomic, assign) ToneMappingOperator toneMapping;
@property(nonatomic, assign) BOOL autoDetectHDR;

+ (instancetype)sharedPipeline;

- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error;
- (void)shutdown;

- (MTLPixelFormat)hdrPixelFormat;
- (MTLPixelFormat)sdrPixelFormat;

- (id<MTLTexture>)createHDRTextureWithWidth:(NSUInteger)width height:(NSUInteger)height;
- (id<MTLTexture>)createIntermediateTextureWithWidth:(NSUInteger)width height:(NSUInteger)height;

- (void)toneMapHDRTexture:(id<MTLTexture>)hdrTexture
                 toSDRTexture:(id<MTLTexture>)sdrTexture
                 commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

- (void)renderWithEDR:(id<MTLTexture>)texture
        commandBuffer:(id<MTLCommandBuffer>)commandBuffer
            headroom:(float)headroom;

- (BOOL)detectHDRDisplay;
- (float)currentEDRHeadroom;

- (NSData *)generateHDR10Metadata;

@end
