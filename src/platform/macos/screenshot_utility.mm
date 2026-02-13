// Add screenshot functionality to StandaloneAppDelegate.mm
//
// Thread-safety + GPU readback notes:
// - UI entrypoints must run on main thread (AppKit)
// - Actual GPU readback must be synchronized with the renderer command buffer
//   to avoid reading from drawable textures before rendering completes.
// - All shared state access is protected by @synchronized blocks
// - GPU readback is ordered after rendering via command buffer completion handler
// - All allocations are validated with NULL checks
// - All AppKit operations are asserted to run on main thread

#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#import <os/log.h>

#import "StandaloneAppDelegate.h"

typedef void (^SCScreenshotEncodeHook)(id<MTLCommandBuffer> commandBuffer,
                                       id<MTLTexture> sourceTexture);

// Logging for debugging thread safety issues
static os_log_t SCScreenshotLog(void) {
  static os_log_t log = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    log = os_log_create("com.shadercandy", "screenshot");
  });
  return log;
}

static inline void SCAssertMainThread(void) {
  NSCAssert([NSThread isMainThread], @"Screenshot UI must run on main thread");
}

static inline void SCDispatchToMain(void (^block)(void)) {
  if ([NSThread isMainThread]) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), block);
  }
}

// Thread-safe getter for shared state with validation
static MTKView *SCGetMetalViewSafely(StandaloneAppDelegate *delegate) {
  if (!delegate) return nil;
  @synchronized(delegate) {
    MTKView *view = delegate.metalView;
    // Validate that view is still valid and has a device
    if (view && view.device) {
      return view;
    }
  }
  return nil;
}

// Thread-safe getter for renderer with validation
static MetalRenderer *SCGetRendererSafely(StandaloneAppDelegate *delegate) {
  if (!delegate) return nil;
  @synchronized(delegate) {
    MetalRenderer *renderer = delegate.renderer;
    // Validate that renderer is still valid and has command queue
    if (renderer && renderer.commandQueue) {
      return renderer;
    }
  }
  return nil;
}

// Thread-safe getter for current shader name
static NSString *SCGetCurrentShaderNameSafely(StandaloneAppDelegate *delegate) {
  if (!delegate) return @"shader";
  @synchronized(delegate) {
    NSString *name = delegate.currentShader;
    return (name && name.length > 0) ? [name copy] : @"shader";
  }
}

// Thread-safe getter for window controller
static NSWindow *SCGetWindowSafely(StandaloneAppDelegate *delegate) {
  if (!delegate) return nil;
  @synchronized(delegate) {
    NSWindow *window = delegate.windowController.window ?: delegate.window;
    return window;
  }
}

static bool SCMulSizeT(size_t a, size_t b, size_t *out) {
  if (!out)
    return false;
  return !__builtin_mul_overflow(a, b, out);
}

static size_t SCAlignUp(size_t value, size_t alignment) {
  if (alignment == 0)
    return value;
  const size_t mask = alignment - 1;
  return (value + mask) & ~mask;
}

static NSString *SCStringOrFallback(NSString *value, NSString *fallback) {
  return (value.length > 0) ? value : fallback;
}

static void SCPresentErrorAlert(NSWindow *window, NSString *title,
                                NSString *info) {
  SCAssertMainThread();
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = SCStringOrFallback(title, @"Screenshot Error");
  alert.informativeText = SCStringOrFallback(info, @"Unknown error");
  [alert addButtonWithTitle:@"OK"];

  if (window) {
    // Sheet when possible; fall back to modal.
    [alert beginSheetModalForWindow:window completionHandler:nil];
  } else {
    [alert runModal];
  }
}

static NSData *SCCreatePNGDataFromBGRABytes(const uint8_t *bytes,
                                              size_t width,
                                              size_t height,
                                              size_t bytesPerRow,
                                              NSError **outError) {
  // Validate all input parameters
  if (!bytes || width == 0 || height == 0 || bytesPerRow == 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:1
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Invalid image buffer"
                                 }];
    }
    return nil;
  }

  // Validate stride to prevent buffer overreads in CoreGraphics.
  // Minimum bytes per row must be width * 4 (BGRA8 = 4 bytes per pixel)
  size_t minBytesPerRow = 0;
  if (!SCMulSizeT(width, 4, &minBytesPerRow) || minBytesPerRow == 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:8
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Image width overflow"
                                 }];
    }
    return nil;
  }

  if (bytesPerRow < minBytesPerRow) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:9
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Invalid row stride (too small)"
                                 }];
    }
    return nil;
  }

  // Validate that bytesPerRow is reasonable (prevent integer overflow in total size)
  size_t totalBytes = 0;
  if (!SCMulSizeT(bytesPerRow, height, &totalBytes) || totalBytes == 0) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:10
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Image size overflow"
                                 }];
    }
    return nil;
  }

  // Create color space - validate result
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  if (!colorSpace) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:2
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to create color space"
                                 }];
    }
    return nil;
  }

  // Metal drawable is BGRA8; this bitmap info matches BGRA byte order.
  // kCGBitmapByteOrder32Little: BGRA byte order (little-endian)
  // kCGImageAlphaPremultipliedFirst: Alpha is first byte (B in BGRA)
  const CGBitmapInfo bitmapInfo = (CGBitmapInfo)(kCGBitmapByteOrder32Little |
                                                 kCGImageAlphaPremultipliedFirst);

  // Create bitmap context - validate result
  CGContextRef context =
      CGBitmapContextCreate((void *)bytes, (size_t)width, (size_t)height, 8,
                            (size_t)bytesPerRow, colorSpace, bitmapInfo);
  if (!context) {
    CGColorSpaceRelease(colorSpace);
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:3
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to create bitmap context"
                                 }];
    }
    return nil;
  }

  // Create CGImage from context - validate result
  CGImageRef cgImage = CGBitmapContextCreateImage(context);
  if (!cgImage) {
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:4
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to create CGImage"
                                 }];
    }
    return nil;
  }

  // Allocate mutable data for PNG encoding - validate result
  NSMutableData *pngData = [NSMutableData data];
  if (!pngData) {
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:5
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to allocate PNG buffer"
                                 }];
    }
    return nil;
  }

  // Create image destination for PNG encoding - validate result
  CGImageDestinationRef dest = CGImageDestinationCreateWithData(
      (__bridge CFMutableDataRef)pngData,
      (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
  if (!dest) {
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:6
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to create PNG destination"
                                 }];
    }
    return nil;
  }

  // Add image to destination and finalize PNG encoding
  CGImageDestinationAddImage(dest, cgImage, NULL);
  const BOOL ok = CGImageDestinationFinalize(dest);
  
  // Clean up CoreGraphics resources in reverse order of allocation
  CFRelease(dest);
  CGImageRelease(cgImage);
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);

  if (!ok) {
    if (outError) {
      *outError = [NSError errorWithDomain:@"ShaderCandy.Screenshot"
                                     code:7
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to finalize PNG encoding"
                                 }];
    }
    return nil;
  }

  return [pngData copy];
}

@implementation StandaloneAppDelegate (Screenshot)

- (void)saveScreenshot {
  // AppKit entrypoint: always execute on main thread.
  if (![NSThread isMainThread]) {
    SCDispatchToMain(^{
      [self saveScreenshot];
    });
    return;
  }

  SCAssertMainThread();

  // Get window safely with thread synchronization
  NSWindow *window = SCGetWindowSafely(self);

  // Thread-safe re-entrancy guard to avoid stacking screenshot operations.
  BOOL alreadyInFlight = NO;
  @synchronized(self) {
    NSNumber *inFlight = (NSNumber *)objc_getAssociatedObject(
        self, @selector(sc_screenshotInFlight));
    alreadyInFlight = inFlight.boolValue;
    if (!alreadyInFlight) {
      objc_setAssociatedObject(self, @selector(sc_screenshotInFlight), @YES,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  }
  if (alreadyInFlight) {
    SCPresentErrorAlert(window, @"Screenshot",
                        @"A screenshot is already in progress");
    return;
  }

  // Get renderer and view safely with thread synchronization
  MetalRenderer *renderer = SCGetRendererSafely(self);
  MTKView *view = SCGetMetalViewSafely(self);
  NSString *shaderName = SCGetCurrentShaderNameSafely(self);

  if (!renderer || !view) {
    @synchronized(self) {
      objc_setAssociatedObject(self, @selector(sc_screenshotInFlight), nil,
                               OBJC_ASSOCIATION_ASSIGN);
    }
    SCPresentErrorAlert(window, @"Screenshot Error",
                        @"Renderer is not ready for screenshots");
    return;
  }

  // Avoid stacking multiple in-flight screenshot requests.
  // (Synchronized to prevent races with the render thread consuming the hook.)
  BOOL rendererHasHook = NO;
  @synchronized(renderer) {
    rendererHasHook =
        (objc_getAssociatedObject(renderer, @selector(sc_screenshotHook)) != nil);
  }
  if (rendererHasHook) {
    @synchronized(self) {
      objc_setAssociatedObject(self, @selector(sc_screenshotInFlight), nil,
                               OBJC_ASSOCIATION_ASSIGN);
    }
    SCPresentErrorAlert(window, @"Screenshot",
                        @"A screenshot is already in progress");
    return;
  }

  StandaloneAppDelegate *weakSelf = self;
  NSWindow *weakWindow = window;
  NSString *shaderNameCopy = [shaderName copy];

  void (^clearInFlightOnMain)(void) = ^{
    SCDispatchToMain(^{
      StandaloneAppDelegate *strongSelf = weakSelf;
      if (!strongSelf)
        return;
      @synchronized(strongSelf) {
        objc_setAssociatedObject(strongSelf, @selector(sc_screenshotInFlight), nil,
                                 OBJC_ASSOCIATION_ASSIGN);
      }
    });
  };

  SCScreenshotEncodeHook hook =
      ^(id<MTLCommandBuffer> commandBuffer, id<MTLTexture> sourceTexture) {
        // Validate command buffer and texture - these are critical for GPU readback
        if (!commandBuffer || !sourceTexture) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow,
                                @"Screenshot Error",
                                @"No render target available for screenshot");
          });
          return;
        }

        // Validate pixel format - only BGRA8 formats are supported
        const MTLPixelFormat pf = sourceTexture.pixelFormat;
        if (pf != MTLPixelFormatBGRA8Unorm && pf != MTLPixelFormatBGRA8Unorm_sRGB) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(
                weakWindow, @"Screenshot Error",
                [NSString stringWithFormat:
                              @"Unsupported pixel format: %lu (expected BGRA8)",
                              (unsigned long)pf]);
          });
          return;
        }

        // Validate texture dimensions
        const NSUInteger width = sourceTexture.width;
        const NSUInteger height = sourceTexture.height;
        if (width == 0 || height == 0 || width > 16384 || height > 16384) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                [NSString stringWithFormat:
                                    @"Invalid drawable size: %lux%lu",
                                    (unsigned long)width, (unsigned long)height]);
          });
          return;
        }

        // Compute bytes per row safely with overflow checking
        // Metal requires 256-byte alignment for optimal performance
        size_t unalignedBytesPerRow = 0;
        if (!SCMulSizeT((size_t)width, 4, &unalignedBytesPerRow) ||
            unalignedBytesPerRow == 0) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Image width overflow");
          });
          return;
        }

        // Align bytes per row to 256-byte boundary for Metal blit operations
        const size_t bytesPerRow = SCAlignUp(unalignedBytesPerRow, 256);
        
        // Validate alignment didn't cause overflow
        if (bytesPerRow < unalignedBytesPerRow) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Row stride alignment overflow");
          });
          return;
        }

        // Compute total image size with overflow checking
        size_t bytesPerImage = 0;
        if (!SCMulSizeT(bytesPerRow, (size_t)height, &bytesPerImage) ||
            bytesPerImage == 0) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Image size overflow");
          });
          return;
        }

        // Validate sizes fit in NSUInteger (required for Metal API)
        if (bytesPerRow > (size_t)NSUIntegerMax || bytesPerImage > (size_t)NSUIntegerMax) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Image is too large to capture");
          });
          return;
        }

        // Get Metal device from texture - validate it's available
        id<MTLDevice> device = sourceTexture.device;
        if (!device) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Metal device is not available");
          });
          return;
        }

        // Allocate readback buffer with shared storage mode
        // Shared mode allows CPU access after GPU completes
        id<MTLBuffer> readback =
            [device newBufferWithLength:(NSUInteger)bytesPerImage
                                options:MTLResourceStorageModeShared];
        if (!readback) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Failed to allocate readback buffer");
          });
          return;
        }

        // Validate buffer contents pointer is accessible
        if (!readback.contents) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Readback buffer contents not accessible");
          });
          return;
        }

        // Create blit encoder to copy texture to buffer
        // This must be in the same command buffer to ensure ordering
        id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
        if (!blit) {
          clearInFlightOnMain();
          SCDispatchToMain(^{
            StandaloneAppDelegate *strongSelf = weakSelf;
            if (!strongSelf)
              return;
            SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                @"Failed to create blit encoder");
          });
          return;
        }

        // Encode blit copy into the *same* command buffer so we're ordered after
        // all rendering for this frame. This is critical for race condition prevention.
        const MTLOrigin origin = {0, 0, 0};
        const MTLSize size = {width, height, 1};
        [blit copyFromTexture:sourceTexture
                  sourceSlice:0
                  sourceLevel:0
                 sourceOrigin:origin
                   sourceSize:size
                     toBuffer:readback
            destinationOffset:0
       destinationBytesPerRow:(NSUInteger)bytesPerRow
     destinationBytesPerImage:(NSUInteger)bytesPerImage];
        [blit endEncoding];

        // Register completion handler to process readback after GPU finishes
        // This ensures we don't read the buffer until rendering is complete
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
          @autoreleasepool {
            // Validate command buffer completed successfully
            if (buffer.status != MTLCommandBufferStatusCompleted) {
              NSError *err = buffer.error;
              clearInFlightOnMain();
              SCDispatchToMain(^{
                StandaloneAppDelegate *strongSelf = weakSelf;
                if (!strongSelf)
                  return;
                SCPresentErrorAlert(
                    weakWindow, @"Screenshot Error",
                    [NSString stringWithFormat:@"GPU readback failed: %@",
                                               err.localizedDescription ?: @"unknown"]);
              });
              return;
            }

            // Validate readback buffer is still accessible
            const uint8_t *rawBytes = (const uint8_t *)readback.contents;
            if (!rawBytes) {
              clearInFlightOnMain();
              SCDispatchToMain(^{
                StandaloneAppDelegate *strongSelf = weakSelf;
                if (!strongSelf)
                  return;
                SCPresentErrorAlert(weakWindow, @"Screenshot Error",
                                    @"Readback buffer is not accessible");
              });
              return;
            }

            // Encode PNG from BGRA bytes
            NSError *pngErr = nil;
            NSData *pngData =
                SCCreatePNGDataFromBGRABytes(rawBytes, (size_t)width,
                                             (size_t)height, bytesPerRow,
                                             &pngErr);

            if (!pngData) {
              clearInFlightOnMain();
              SCDispatchToMain(^{
                StandaloneAppDelegate *strongSelf = weakSelf;
                if (!strongSelf)
                  return;
                SCPresentErrorAlert(
                    weakWindow, @"Screenshot Error",
                    [NSString stringWithFormat:@"PNG encoding failed: %@",
                                               pngErr.localizedDescription ?: @"unknown"]);
              });
              return;
            }

            // Present save panel on main thread
            SCDispatchToMain(^{
              StandaloneAppDelegate *strongSelf = weakSelf;
              if (!strongSelf)
                return;
              @synchronized(strongSelf) {
                objc_setAssociatedObject(strongSelf, @selector(sc_screenshotInFlight), nil,
                                         OBJC_ASSOCIATION_ASSIGN);
              }
              [strongSelf _sc_presentSavePanelForPNGData:pngData
                                               shaderName:shaderNameCopy
                                                    width:width
                                                    height:height
                                                    window:weakWindow];
            });
          }
        }];
      };

  // Register hook to be consumed by MetalRenderer on the render thread.
  @synchronized(renderer) {
    objc_setAssociatedObject(renderer, @selector(sc_screenshotHook),
                             [hook copy], OBJC_ASSOCIATION_COPY);
  }

  // Nudge render loop so the hook is consumed promptly.
  [view setNeedsDisplay:YES];
}

// AppKit-only helper (main-thread only).
// Presents a save panel for the PNG data and handles file writing.
- (void)_sc_presentSavePanelForPNGData:(NSData *)pngData
                             shaderName:(NSString *)shaderName
                                  width:(NSUInteger)width
                                 height:(NSUInteger)height
                                 window:(NSWindow *)window {
  // This method must always run on the main thread (AppKit requirement)
  SCAssertMainThread();

  // Validate PNG data
  if (!pngData || pngData.length == 0) {
    SCPresentErrorAlert(window, @"Screenshot Error", @"Empty PNG data");
    return;
  }

  // Create save panel - validate it was created successfully
  NSSavePanel *savePanel = [NSSavePanel savePanel];
  if (!savePanel) {
    SCPresentErrorAlert(window, @"Screenshot Error",
                        @"Failed to create save panel");
    return;
  }

  // Configure save panel
  savePanel.title = @"Save Screenshot";
  savePanel.allowedContentTypes = @[ UTTypePNG ];
  
  // Generate default filename with shader name and dimensions
  NSString *defaultName =
      [NSString stringWithFormat:@"shadercandy_%@_%lux%lu.png",
                                 SCStringOrFallback(shaderName, @"shader"),
                                 (unsigned long)width, (unsigned long)height];
  if (defaultName) {
    savePanel.nameFieldStringValue = defaultName;
  }

  // Get target window safely - use provided window or fall back to delegate's window
  NSWindow *targetWindow = window ?: self.windowController.window ?: self.window;

  // Completion handler for save panel result
  // This block is called when user confirms or cancels the save dialog
  void (^handleSaveResult)(NSModalResponse) = ^(NSModalResponse result) {
    SCDispatchToMain(^{
      // Ensure we're on main thread for AppKit operations
      SCAssertMainThread();
      
      // User cancelled the save dialog
      if (result != NSModalResponseOK)
        return;

      // Get the URL the user selected
      NSURL *url = savePanel.URL;
      if (!url) {
        SCPresentErrorAlert(targetWindow, @"Screenshot Save Error",
                            @"Invalid save location");
        return;
      }

      // Write PNG data to the selected location atomically
      NSError *error = nil;
      if (![pngData writeToURL:url options:NSDataWritingAtomic error:&error]) {
        SCPresentErrorAlert(
            targetWindow, @"Screenshot Save Error",
            [NSString stringWithFormat:@"Failed to save screenshot: %@",
                                       error.localizedDescription ?: @"unknown"]);
        return;
      }
      
      // Success - file was written
      os_log(SCScreenshotLog(), "Screenshot saved to: %{public}@", url.path);
    });
  };

  // Present save panel as sheet if window is available, otherwise as modal
  if (targetWindow) {
    [savePanel beginSheetModalForWindow:targetWindow
                      completionHandler:handleSaveResult];
  } else {
    // No window available (rare). Fall back to app-modal save panel.
    NSModalResponse result = [savePanel runModal];
    handleSaveResult(result);
  }
}

@end
