//
//  MetalResourcePool.mm
//  ShaderCandy
//

#import "MetalResourcePool.h"

@interface MetalResourcePool () {
  NSMutableArray<id<MTLTexture>> *_texturePool;
  NSMutableArray<id<MTLBuffer>> *_bufferPool;
  dispatch_semaphore_t _lock;
}
@end

@implementation MetalResourcePool

- (instancetype)initWithDevice:(id<MTLDevice>)device {
  self = [super init];
  if (self) {
    _device = device;
    _texturePool = [NSMutableArray array];
    _bufferPool = [NSMutableArray array];
    _maxMemoryUsageBytes = 256 * 1024 * 1024; // Default 256MB
    _lock = dispatch_semaphore_create(1);
  }
  return self;
}

- (nullable id<MTLTexture>)getTextureWithDescriptor:
    (MTLTextureDescriptor *)descriptor {
  dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);

  id<MTLTexture> found = nil;
  for (NSUInteger i = 0; i < _texturePool.count; i++) {
    id<MTLTexture> tex = _texturePool[i];
    if (tex.pixelFormat == descriptor.pixelFormat &&
        tex.width == descriptor.width && tex.height == descriptor.height &&
        tex.usage == descriptor.usage &&
        tex.textureType == descriptor.textureType) {
      found = tex;
      [_texturePool removeObjectAtIndex:i];
      break;
    }
  }

  dispatch_semaphore_signal(_lock);

  if (found)
    return found;

  id<MTLTexture> newTex = [_device newTextureWithDescriptor:descriptor];
  if (newTex) {
    // Accurate memory calculation based on pixel format
    NSUInteger bytesPerPixel = 4;
    if (descriptor.pixelFormat == MTLPixelFormatRGBA32Float) {
      bytesPerPixel = 16;
    }
    _currentMemoryUsageBytes += (descriptor.width * descriptor.height * bytesPerPixel);
  }
  return newTex;
}

- (void)returnTexture:(id<MTLTexture>)texture {
  if (!texture)
    return;
  dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
  [_texturePool addObject:texture];
  dispatch_semaphore_signal(_lock);
}

- (nullable id<MTLBuffer>)getBufferWithLength:(NSUInteger)length
                                      options:(MTLResourceOptions)options {
  dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);

  id<MTLBuffer> found = nil;
  for (NSUInteger i = 0; i < _bufferPool.count; i++) {
    id<MTLBuffer> buf = _bufferPool[i];
    // Reuse if buffer is larger or equal to requested length
    if (buf.length >= length && buf.length <= length * 2) {
      found = buf;
      [_bufferPool removeObjectAtIndex:i];
      break;
    }
  }

  dispatch_semaphore_signal(_lock);

  if (found)
    return found;

  id<MTLBuffer> newBuf = [_device newBufferWithLength:length options:options];
  if (newBuf) {
    _currentMemoryUsageBytes += length;
  }
  return newBuf;
}

- (void)returnBuffer:(id<MTLBuffer>)buffer {
  if (!buffer)
    return;
  dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
  [_bufferPool addObject:buffer];
  dispatch_semaphore_signal(_lock);
}

- (void)purgeUnusedResources {
  dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
  [_texturePool removeAllObjects];
  [_bufferPool removeAllObjects];
  _currentMemoryUsageBytes = 0; // Reset estimate
  dispatch_semaphore_signal(_lock);
}

- (void)purgeAllResources {
  [self purgeUnusedResources];
}

@end
