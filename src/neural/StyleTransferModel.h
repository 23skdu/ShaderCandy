//
//  StyleTransferModel.h
//  ShaderCandy
//
//  Individual style transfer model wrapper
//

#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface StyleTransferModel : NSObject

@property(nonatomic, copy, readonly) NSString *styleName;
@property(nonatomic, copy, readonly) NSString *displayName;
@property(nonatomic, copy, readonly) NSString *category;
@property(nonatomic, copy, readonly, nullable) NSString *description;
@property(nonatomic, strong, readonly, nullable) NSImage *previewImage;
@property(nonatomic, assign, readonly) CGSize inputSize;
@property(nonatomic, assign, readonly) float recommendedStrength;
@property(nonatomic, assign, readonly) BOOL isLoaded;

- (instancetype)initWithName:(NSString *)name modelURL:(NSURL *)url;
- (instancetype)initWithBundleStyle:(NSString *)styleName;

- (BOOL)loadWithError:(NSError **)error;
- (void)unload;

- (nullable id<MTLTexture>)transferStyle:(id<MTLTexture>)inputTexture
                          commandBuffer:(id<MTLCommandBuffer>)commandBuffer
                                 strength:(float)strength;

- (void)generatePreviewIfNeeded;

@end

NS_ASSUME_NONNULL_END
