//
//  MetalResourcePool.h
//  ShaderCandy
//
//  Management of reusable Metal textures and buffers to reduce allocations.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetalResourcePool : NSObject

@property(nonatomic, strong, readonly) id<MTLDevice> device;
@property(nonatomic, assign) NSUInteger maxMemoryUsageBytes;
@property(nonatomic, readonly) NSUInteger currentMemoryUsageBytes;

- (instancetype)initWithDevice:(id<MTLDevice>)device;

// Texture management
- (nullable id<MTLTexture>)getTextureWithDescriptor:
    (MTLTextureDescriptor *)descriptor;
- (void)returnTexture:(id<MTLTexture>)texture;

// Buffer management
- (nullable id<MTLBuffer>)getBufferWithLength:(NSUInteger)length
                                      options:(MTLResourceOptions)options;
- (void)returnBuffer:(id<MTLBuffer>)buffer;

// Cleanup
- (void)purgeUnusedResources;
- (void)purgeAllResources;

@end

NS_ASSUME_NONNULL_END
