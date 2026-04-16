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

    // Try different heap sizes from largest to smallest, starting with more conservative sizes
    NSArray<NSNumber *> *heapSizes = @[
        @(64 * 1024 * 1024),  // 64MB
        @(32 * 1024 * 1024),  // 32MB
        @(16 * 1024 * 1024),  // 16MB
        @(8 * 1024 * 1024),   // 8MB
        @(4 * 1024 * 1024),   // 4MB
        @(2 * 1024 * 1024)    // 2MB
    ];

    for (NSNumber *heapSize in heapSizes) {
      MTLHeapDescriptor *heapDesc = [[MTLHeapDescriptor alloc] init];
      heapDesc.size = heapSize.unsignedLongValue;
      heapDesc.storageMode = MTLStorageModeShared;
      heapDesc.type = MTLHeapTypeAutomatic;

      _heap = [_device newHeapWithDescriptor:heapDesc];
      if (_heap) {
        NSLog(@"MetalHeapManager: Created heap with size %lu", (unsigned long)heapSize.unsignedLongValue);
        return self;
      } else {
        NSLog(@"MetalHeapManager: Failed to create heap with size %lu", (unsigned long)heapSize.unsignedLongValue);
      }
    }

    // If we reach here, all heap sizes failed
    NSLog(@"MetalHeapManager: Failed to create heap with any size - Metal may not be supported");
    return nil;
  }
  return nil;
}

- (nullable id<MTLBuffer>)newBufferWithLength:(NSUInteger)length
                                      options:(MTLResourceOptions)options {
  // Check if heap can fit
  MTLSizeAndAlign sizeAlign =
      [_device heapBufferSizeAndAlignWithLength:length options:options];
  NSLog(@"MetalHeapManager: Attempting to create buffer of length %lu (aligned size: %lu, alignment: %lu)", (unsigned long)length, (unsigned long)sizeAlign.size, (unsigned long)sizeAlign.align);
  
  NSUInteger maxAvailable = [_heap maxAvailableSizeWithAlignment:sizeAlign.align];
  NSLog(@"MetalHeapManager: Heap max available with alignment %lu: %lu", (unsigned long)sizeAlign.align, (unsigned long)maxAvailable);
  
  if (sizeAlign.size > maxAvailable) {
    NSLog(@"MetalHeapManager: Buffer creation failed - requested size %lu > available %lu", (unsigned long)sizeAlign.size, (unsigned long)maxAvailable);
    return nil;
  }

  id<MTLBuffer> buffer = [_heap newBufferWithLength:length options:options];
  if (!buffer) {
    NSLog(@"MetalHeapManager: Buffer creation failed - heap returned nil");
  }
  return buffer;
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
