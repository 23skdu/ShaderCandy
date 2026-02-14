//
//  ShaderScreenshotGenerator.mm
//  ShaderCandy
//
//  Tool to generate high-resolution screenshots for all shaders.
//

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "../metal/MetalRenderer.h"

// Helper to save PNG
static NSData *CreatePNGData(const uint8_t *bytes, size_t width, size_t height,
                             size_t bytesPerRow) {
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  const CGBitmapInfo bitmapInfo =
      (CGBitmapInfo)(kCGBitmapByteOrder32Little |
                     kCGImageAlphaPremultipliedFirst);
  CGContextRef context = CGBitmapContextCreate(
      (void *)bytes, width, height, 8, bytesPerRow, colorSpace, bitmapInfo);
  if (!context) {
    CGColorSpaceRelease(colorSpace);
    return nil;
  }
  CGImageRef cgImage = CGBitmapContextCreateImage(context);
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);

  NSMutableData *pngData = [NSMutableData data];
  CGImageDestinationRef dest = CGImageDestinationCreateWithData(
      (__bridge CFMutableDataRef)pngData,
      (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
  if (!dest) {
    CGImageRelease(cgImage);
    return nil;
  }
  CGImageDestinationAddImage(dest, cgImage, NULL);
  CGImageDestinationFinalize(dest);
  CFRelease(dest);
  CGImageRelease(cgImage);
  return pngData;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSLog(@"Starting Shader Screenshot Generator...");

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
      NSLog(@"Error: No Metal device found.");
      return 1;
    }

    NSError *error = nil;
    MetalRenderer *renderer = [MetalRenderer rendererWithDevice:device
                                                          error:&error];
    if (!renderer) {
      NSLog(@"Error initializing renderer: %@", error);
      return 1;
    }

    // Configure renderer
    CGSize resolution = CGSizeMake(1920, 1080); // Full HD
    [renderer setViewportSize:resolution];
    [renderer setParticlesEnabled:YES];
    [renderer setBloomEnabled:YES];

    NSArray<NSString *> *shaders = [renderer availableShaderNames];
    NSLog(@"Found %lu shaders.", (unsigned long)shaders.count);

    NSString *outputDir = @"screenshots";
    [[NSFileManager defaultManager] createDirectoryAtPath:outputDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    // Create an offscreen texture to render into
    MTLTextureDescriptor *texDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:resolution.width
                                    height:resolution.height
                                 mipmapped:NO];
    texDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    texDesc.storageMode = MTLStorageModeShared;

    id<MTLTexture> targetTexture = [device newTextureWithDescriptor:texDesc];
    if (!targetTexture) {
      NSLog(@"Error: Failed to create target texture.");
      return 1;
    }

    for (NSString *shader in shaders) {
      NSLog(@"Processing shader: %@", shader);

      NSError *renderError = nil;
      if (![renderer loadShaderWithName:shader error:&renderError]) {
        NSLog(@"  Failed to load shader: %@", renderError);
        continue;
      }

      if (!renderer.currentPipeline.renderPipeline) {
        NSLog(@"  Shader '%@' has no render pipeline (likely a compute/audio "
              @"shader), skipping.",
              shader);
        continue;
      }

      // Warm up / simulate
      NSLog(@"  Warming up...");
      for (int i = 0; i < 60; i++) {
        [renderer updateUniformsWithTime:(NSTimeInterval)i * (1.0 / 60.0)
                           mousePosition:NSZeroPoint
                            mouseButtons:0
                                   speed:1.0f
                               intensity:1.0f
                                 gravity:1.0f
                                  height:resolution.height];

        [renderer renderToTexture:targetTexture];
      }

      // Capture the last frame
      NSLog(@"  Capturing frame...");
      NSUInteger bytesPerRow = resolution.width * 4;
      NSUInteger bytesPerImage = bytesPerRow * resolution.height;
      id<MTLBuffer> readBuffer =
          [device newBufferWithLength:bytesPerImage
                              options:MTLResourceStorageModeShared];
      if (!readBuffer) {
        NSLog(@"  Failed to create read buffer.");
        continue;
      }

      id<MTLCommandBuffer> cmdBuffer = [renderer.commandQueue commandBuffer];
      if (!cmdBuffer) {
        NSLog(@"  Failed to create command buffer.");
        continue;
      }

      id<MTLBlitCommandEncoder> blit = [cmdBuffer blitCommandEncoder];
      if (!blit) {
        NSLog(@"  Failed to create blit encoder.");
        continue;
      }

      [blit copyFromTexture:targetTexture
                       sourceSlice:0
                       sourceLevel:0
                      sourceOrigin:MTLOriginMake(0, 0, 0)
                        sourceSize:MTLSizeMake(resolution.width,
                                               resolution.height, 1)
                          toBuffer:readBuffer
                 destinationOffset:0
            destinationBytesPerRow:bytesPerRow
          destinationBytesPerImage:bytesPerImage];
      [blit endEncoding];
      [cmdBuffer commit];
      [cmdBuffer waitUntilCompleted];

      // Read bytes and save
      NSLog(@"  Encoding PNG...");
      uint8_t *bytes = (uint8_t *)readBuffer.contents;
      if (!bytes) {
        NSLog(@"  Buffer contents are null.");
        continue;
      }

      NSData *pngData = CreatePNGData(bytes, resolution.width,
                                      resolution.height, bytesPerRow);

      if (!pngData) {
        NSLog(@"  Failed to encode PNG.");
        continue;
      }

      NSString *filename =
          [NSString stringWithFormat:@"%@/%@.png", outputDir, shader];
      if ([pngData writeToFile:filename atomically:YES]) {
        NSLog(@"  Saved screenshot to %@", filename);
      } else {
        NSLog(@"  Failed to save screenshot.");
      }
    }

    NSLog(@"Done.");
  }
  return 0;
}
