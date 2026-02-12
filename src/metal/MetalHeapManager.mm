//
//  MetalHeapManager.mm
//  ShaderCandy
//

#import "MetalHeapManager.h"

@implementation MetalHeapManager

- (instancetype)initWithDevice:(id<MTLDevice>)device size:(NSUInteger)size {
  self = [super init];
  if (self) {
    _device = device;

    MTLHeapDescriptor *heapDesc = [[MTLHeapDescriptor alloc] init];
    heapDesc.size = size;
    heapDesc.storageMode = MTLStorageModeShared;
    heapDesc.type = MTLHeapTypePlacement; // Use placement for precise control

    _heap = [_device newHeapWithDescriptor:heapDesc];
  }
  return self;
}

- (nullable id<MTLBuffer>)newBufferWithLength:(NSUInteger)length
                                      options:(MTLResourceOptions)options {
  // Check if heap can fit
  MTLSizeAndAlign sizeAlign =
      [_device heapBufferSizeAndAlignWithLength:length options:options];
  if (sizeAlign.size > [_heap maxAvailableSizeWithAlignment:sizeAlign.align]) {
    return nil;
  }

  return [_heap newBufferWithLength:length options:options];
}

- (nullable id<MTLTexture>)newTextureWithDescriptor:
    (MTLTextureDescriptor *)descriptor {
  MTLSizeAndAlign sizeAlign =
      [_device heapTextureSizeAndAlignWithDescriptor:descriptor];
  if (sizeAlign.size > [_heap maxAvailableSizeWithAlignment:sizeAlign.align]) {
    return nil;
  }

  return [_heap newTextureWithDescriptor:descriptor];
}

@end
