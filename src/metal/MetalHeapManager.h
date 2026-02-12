//
//  MetalHeapManager.h
//  ShaderCandy
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetalHeapManager : NSObject

@property(nonatomic, strong, readonly) id<MTLDevice> device;
@property(nonatomic, strong, readonly) id<MTLHeap> heap;

- (instancetype)initWithDevice:(id<MTLDevice>)device size:(NSUInteger)size;

- (nullable id<MTLBuffer>)newBufferWithLength:(NSUInteger)length
                                      options:(MTLResourceOptions)options;

- (nullable id<MTLTexture>)newTextureWithDescriptor:
    (MTLTextureDescriptor *)descriptor;

@end

NS_ASSUME_NONNULL_END
