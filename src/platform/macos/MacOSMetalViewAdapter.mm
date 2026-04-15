//
//  MacOSMetalViewAdapter.mm
//  ShaderCandy
//
//  Thin delegation layer implementation
//

#import "MacOSMetalViewAdapter.h"
#import "../../audio/SoundscapeGenerator.h"
#import "../../metal/MetalRenderer.h"
#import "../../metal/MetalSharedState.h"
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MacOSMetalViewAdapter ()

@property(nonatomic, strong, nullable) MTKView *mtkView;
@property(nonatomic, strong, nullable) NSDate *startTime;
@property(nonatomic, assign) NSInteger frameCount;
@property(nonatomic, strong, nullable) NSString *currentShaderName;
@property(nonatomic, strong, nullable) NSArray<NSString *> *availableShaders;
@property(nonatomic, assign) BOOL isCycling;
@property(nonatomic, assign) NSTimeInterval cycleInterval;
@property(nonatomic, strong, nullable) NSDate *lastCycleTime;

@end

@implementation MacOSMetalViewAdapter

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  self = [super initWithFrame:frame isPreview:isPreview];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (void)commonInit {
  // Register Defaults
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults registerDefaults:@{
    @"selectedShader" : @"default",
    @"preferredFPS" : @60,
    @"enableBloom" : @YES,
    @"speed" : @1.0,
    @"intensity" : @1.0,
    @"gravity" : @1.0,
    @"hotReload" : @NO,
    @"showMetrics" : @NO,
    @"autoScaling" : @YES,
    @"soundscape" : @NO,
    @"cycleShaders" : @YES,
    @"cycleInterval" : @15.0
  }];

  _currentShaderName = [defaults stringForKey:@"selectedShader"];
  NSLog(@"MacOSMetalViewAdapter: commonInit - selectedShader from defaults: %@", _currentShaderName);
  
  _preferredFPS = [defaults integerForKey:@"preferredFPS"];
  _enableBloom = [defaults boolForKey:@"enableBloom"];
  _speed = [defaults floatForKey:@"speed"];
  _intensity = [defaults floatForKey:@"intensity"];
  _gravity = [defaults floatForKey:@"gravity"];
  _enableHotReload = [defaults boolForKey:@"hotReload"];

  _isCycling = [defaults boolForKey:@"cycleShaders"];
  _cycleInterval = [defaults doubleForKey:@"cycleInterval"];
  _lastCycleTime = [NSDate date];
  self.animationTimeInterval = 1.0 / (double)_preferredFPS;

  self.wantsLayer = YES;
  NSLog(@"MacOSMetalViewAdapter: Initializing with frame %@",
        NSStringFromRect(self.bounds));

  // Pre-discover shaders early so they're available for configureSheet
  // We need to do this without Metal device to populate the menu
  [self discoverShadersEarly];
}

// Discover shaders early without requiring Metal device
- (void)discoverShadersEarly {
  NSMutableArray *shaders = [NSMutableArray array];
  NSFileManager *fm = [NSFileManager defaultManager];
  
  // Try multiple paths to find shaders
  NSArray *pathsToTry = @[];
  
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *resourcePath = [bundle resourcePath];
  NSString *bundlePath = [bundle bundlePath];
  
  // Build list of paths to try
  NSMutableArray *candidates = [NSMutableArray array];
  
  // Standard resource path
  [candidates addObject:[resourcePath stringByAppendingPathComponent:@"shaders"]];
  // Bundle Contents/Resources path
  [candidates addObject:[bundlePath stringByAppendingPathComponent:@"Contents/Resources/shaders"]];
  // Direct in Resources
  [candidates addObject:[resourcePath stringByAppendingPathComponent:@"Resources/shaders"]];
  // Parent bundle's shaders
  [candidates addObject:[[bundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"shaders"]];
  
  NSString *shadersPath = nil;
  for (NSString *candidate in candidates) {
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:candidate isDirectory:&isDir] && isDir) {
      shadersPath = candidate;
      NSLog(@"MacOSMetalViewAdapter: Found shaders at: %@", shadersPath);
      break;
    }
  }
  
  if (!shadersPath) {
    NSLog(@"MacOSMetalViewAdapter: Shaders directory not found in any location, using defaults");
    _availableShaders = @[
      @"default", @"spiral", @"plasma", @"tunnel", @"nebula", @"mandelbulb",
      @"mandelbrot", @"julia_set", @"reaction_diffusion", @"starfield_warp",
      @"cosmic_kaleido", @"vortex_dream", @"quantum_crystalline"
    ];
    return;
  }

  // Scan for .metal files
  NSDirectoryEnumerator *enumerator =
      [fm enumeratorAtURL:[NSURL fileURLWithPath:shadersPath]
          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                             options:NSDirectoryEnumerationSkipsHiddenFiles
                        errorHandler:nil];

  for (NSURL *fileURL in enumerator) {
    NSString *fileName;
    [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:nil];

    NSNumber *isDirectory;
    [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

    if (![isDirectory boolValue] && [fileName hasSuffix:@".metal"]) {
      NSString *name = [fileName stringByDeletingPathExtension];
      // Skip utility shaders
      if (![name isEqualToString:@"common"] &&
          ![name isEqualToString:@"utils"] &&
          ![name isEqualToString:@"ShaderInterop"] &&
          ![name isEqualToString:@"bloom"] &&
          ![name isEqualToString:@"particles"] &&
          ![name isEqualToString:@"debug_overlay"]) {
        [shaders addObject:name];
      }
    }
  }

  // Also look in subdirectories (effects, music, etc.)
  NSArray *subDirs = @[@"effects", @"music", @"neural", @"audio", @"system", @"base"];
  for (NSString *subDir in subDirs) {
    NSString *subPath = [shadersPath stringByAppendingPathComponent:subDir];
    if ([fm fileExistsAtPath:subPath]) {
      NSLog(@"MacOSMetalViewAdapter: Scanning subdirectory: %@", subPath);
      NSDirectoryEnumerator *subEnum =
          [fm enumeratorAtURL:[NSURL fileURLWithPath:subPath]
              includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                         options:NSDirectoryEnumerationSkipsHiddenFiles
                    errorHandler:nil];
      for (NSURL *fileURL in subEnum) {
        NSString *fileName;
        [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:nil];
        if ([fileName hasSuffix:@".metal"]) {
          NSString *name = [fileName stringByDeletingPathExtension];
          if (![shaders containsObject:name]) {
            [shaders addObject:name];
          }
        }
      }
    }
  }

  [shaders sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

  // Always ensure we have at least one valid shader (note: "default" shader doesn't exist)
  if (shaders.count == 0) {
    shaders = [@[
      @"spiral", @"plasma", @"tunnel", @"nebula", @"mandelbulb",
      @"mandelbrot", @"julia_set", @"reaction_diffusion", @"starfield_warp"
    ] mutableCopy];
  }

  _availableShaders = [shaders copy];
  NSLog(@"MacOSMetalViewAdapter: Early discovered %lu shaders: %@",
        (unsigned long)_availableShaders.count, _availableShaders);
}

- (void)setFrame:(NSRect)frame {
  [super setFrame:frame];
  
  if (_mtkView) {
    _mtkView.frame = self.bounds;
  }
  // Retry Metal setup if previous attempt was deferred due to small bounds
  if (!self.mtkView && (self.isPreview || (NSWidth(self.bounds) >= 1.0 && NSHeight(self.bounds) >= 1.0))) {
    [self setupMetal];
  }
}

- (void)startAnimation {
  [super startAnimation];
  NSLog(@">>>>> startAnimation called, isPreview=%d", self.isPreview);

  // Tahoe/macOS 15 Fix: Ensure zero bounds are recovered for full screen
  if (!self.isPreview && NSWidth(self.bounds) < 1.0) {
    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
    [self setFrame:screen.frame];
  }

  if (!self.mtkView) {
    [self setupMetal];
  }
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  NSLog(@">>>>> viewDidMoveToWindow called");
  
  // Ensure proper frame when moving to window
  if (self.window && (NSWidth(self.bounds) < 1.0 || NSHeight(self.bounds) < 1.0)) {
    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
    [self setFrame:screen.frame];
  }
  
  if (!self.mtkView) {
    [self setupMetal];
  }
}

- (void)setupMetal {
  if (self.mtkView)
    return;

  // Check bounds - skip initialization only if both dimensions are exactly zero
  // Small but non-zero bounds (preview) should still initialize Metal
  CGFloat width = NSWidth(self.bounds);
  CGFloat height = NSHeight(self.bounds);
  
  // Allow initialization for preview mode with even tiny bounds, or full-screen mode
  // Only skip if literally zero dimensions
  BOOL hasValidBounds = (width > 0 && height > 0) || self.isPreview;
  if (!hasValidBounds && (width < 1.0 || height < 1.0)) {
    // For preview mode, we actually still want to try with tiny bounds
    if (!self.isPreview) {
      return;
    }
  }
  
  id<MTLDevice> metalDevice = MTLCreateSystemDefaultDevice();
  if (!metalDevice) {
    NSLog(@"MacOSMetalViewAdapter: Failed to create Metal device");
    return;
  }

  // Create MTKView with valid device
  self.mtkView = [[MTKView alloc] initWithFrame:self.bounds device:metalDevice];
  self.mtkView.delegate = self;
  self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  self.mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
  self.mtkView.preferredFramesPerSecond = _preferredFPS;
  self.mtkView.enableSetNeedsDisplay = NO; // Driven by display link
  self.mtkView.paused = NO;
  self.mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
  self.mtkView.layer.backgroundColor = [[NSColor blackColor] CGColor];
  [self addSubview:self.mtkView];

  // Create renderer
  NSError *error = nil;
  _renderer = [MetalRenderer rendererWithDevice:self.mtkView.device
                                          error:&error];
  if (error || !_renderer) {
    NSLog(@"MacOSMetalViewAdapter: Failed to create renderer: %@", error);
    return;
  }

  _renderer.developmentMode = _enableHotReload;
  _renderer.hotReloadEnabled = _enableHotReload;
  _renderer.preferredFPS = _preferredFPS;

  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  _renderer.showDebugOverlay = [defaults boolForKey:@"showMetrics"];
  _renderer.autoScalingEnabled = [defaults boolForKey:@"autoScaling"];
  [SoundscapeGenerator sharedGenerator].enabled =
      [defaults boolForKey:@"soundscape"];

  [_renderer setBloomEnabled:_enableBloom];
  [_renderer setViewportSize:self.mtkView.drawableSize];

  // Discover shaders - prefer renderer discovery but use early discovery as fallback
  NSArray *rendererShaders = [_renderer availableShaderNames];
  if (rendererShaders.count > 0) {
    _availableShaders = rendererShaders;
  } else if (_availableShaders.count == 0) {
    _availableShaders = @[@"default", @"spiral", @"plasma", @"tunnel", @"nebula", @"mandelbulb", @"aurora", @"starfield"];
  }

  // Set device before loading shaders
  self.mtkView.device = _renderer.device;

  // Load default/saved shader
  if (_availableShaders.count > 0) {
    if ([_currentShaderName isEqualToString:@"Cycle All"] ||
        !_currentShaderName) {
      _isCycling = YES;
      _currentShaderName = _availableShaders.firstObject;
    } else if (![_availableShaders containsObject:_currentShaderName]) {
      _currentShaderName = _availableShaders.firstObject;
    }
    [self loadShaders];
  }
  _startTime = [NSDate date];
}

- (void)loadShaders {
  if (!_renderer || !_currentShaderName) {
    return;
  }
  
  NSError *error = nil;
  BOOL success = [_renderer setActiveShader:_currentShaderName error:&error];
  
  if (!success && error) {
    // Try other shaders as fallback
    for (NSString *shaderName in _availableShaders) {
      if ([shaderName isEqualToString:_currentShaderName])
        continue;
      
      NSError *fallbackError = nil;
      if ([_renderer setActiveShader:shaderName error:&fallbackError]) {
        NSLog(@"MacOSMetalViewAdapter: Successfully loaded fallback shader '%@'", shaderName);
        _currentShaderName = shaderName;
        return;
      }
    }
    
    // Last resort: try loading "default" directly
    NSError *defaultError = nil;
    if ([_renderer setActiveShader:@"default" error:&defaultError]) {
      _currentShaderName = @"default";
      return;
    }
    
    NSLog(@"MacOSMetalViewAdapter: ALL shaders failed to load");
    return;
  }
  
  // Shader loaded successfully
  NSLog(@"MacOSMetalViewAdapter: Shader '%@' loaded and ready", _currentShaderName);
}

- (void)reloadShaders {
  if (!_renderer)
    return;

  NSError *error = nil;
  [_renderer reloadCurrentShader:&error];
}

- (void)selectShaderNamed:(NSString *)name {
  if (![_availableShaders containsObject:name]) {
    return;
  }

  _currentShaderName = name;
  [self loadShaders];

  // Save to defaults
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setObject:name forKey:@"selectedShader"];
  [defaults synchronize];
}

- (void)animateOneFrame {
  if (_isCycling) {
    NSTimeInterval elapsed =
        [[NSDate date] timeIntervalSinceDate:_lastCycleTime];
    if (elapsed > _cycleInterval) {
      [self cycleToNextShader];
    }
  }
  // Drive rendering via ScreenSaverView heartbeat for preview compatibility
  [self setNeedsDisplay:YES];
}

- (void)cycleToNextShader {
  if (_availableShaders.count == 0)
    return;

  NSUInteger index = [_availableShaders indexOfObject:_currentShaderName];
  index = (index == NSNotFound) ? 0 : (index + 1) % _availableShaders.count;
  _currentShaderName = _availableShaders[index];
  _lastCycleTime = [NSDate date];

  NSError *error = nil;
  [_renderer transitionToShaderNamed:_currentShaderName
                            duration:2.0
                               error:&error];
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  [_renderer setViewportSize:size];
}

- (void)drawInMTKView:(MTKView *)view {
  // Skip all debug output in release - causes major slowdown
  
  if (!_renderer) {
    return;
  }
  if (!view.currentDrawable) {
    return;
  }
  if (!view.currentRenderPassDescriptor) {
    return;
  }
  if (!_renderer.currentPipeline) {
    return;
  }

  // Update uniforms
  NSTimeInterval elapsed = [[MetalSharedState sharedState] synchronizedTime];

  NSPoint mousePos =
      [self.window
          convertRectFromScreen:NSMakeRect([NSEvent mouseLocation].x,
                                           [NSEvent mouseLocation].y, 0, 0)]
          .origin;

  [_renderer updateUniformsWithTime:elapsed
                      mousePosition:mousePos
                       mouseButtons:[NSEvent pressedMouseButtons]
                              speed:_speed
                          intensity:_intensity
                            gravity:_gravity
                             height:NSHeight(self.bounds)];

  [_renderer renderToDrawable:view.currentDrawable
         renderPassDescriptor:view.currentRenderPassDescriptor];

  _frameCount++;
}

#pragma mark - Input Handling

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)keyDown:(NSEvent *)event {
  NSString *chars = [event charactersIgnoringModifiers];
  if ([chars isEqualToString:@"d"] || [chars isEqualToString:@"D"]) {
    if (_renderer) {
      _renderer.showDebugOverlay = !_renderer.showDebugOverlay;
      // Save state
      ScreenSaverDefaults *defaults = [ScreenSaverDefaults
          defaultsForModuleWithName:@"com.shadercandy.screensaver"];
      [defaults setBool:_renderer.showDebugOverlay forKey:@"showMetrics"];
      [defaults synchronize];
    }
  } else if ([chars isEqualToString:@"s"] || [chars isEqualToString:@"S"]) {
    // Screenshot shortcut for screensaver
    [self saveScreenshot];
  } else if ([chars isEqualToString:@"t"] || [chars isEqualToString:@"T"]) {
    // Test all shaders
    if (_renderer) {
      [_renderer testAllShaders];
    }
  } else {
    [super keyDown:event];
  }
}

#pragma mark - Screenshot

- (void)saveScreenshot {
  if (!_renderer || !_mtkView) {
    NSLog(@"Cannot save screenshot: renderer or view not available");
    return;
  }
  
  id<CAMetalDrawable> drawable = _mtkView.currentDrawable;
  if (!drawable) {
    NSLog(@"Cannot save screenshot: no current drawable");
    return;
  }
  
  // Get the texture from the drawable
  id<MTLTexture> texture = drawable.texture;
  if (!texture) {
    NSLog(@"Cannot save screenshot: no texture available");
    return;
  }
  
  // Create save panel
  NSSavePanel *savePanel = [NSSavePanel savePanel];
  savePanel.title = @"Save Screenshot";
  savePanel.nameFieldStringValue = [NSString stringWithFormat:@"shadercandy_screenshot_%@.png", _currentShaderName ?: @"shader"];
  savePanel.allowedContentTypes = @[[UTType typeWithIdentifier:@"public.png"]];
  savePanel.directoryURL = [NSURL fileURLWithPath:NSHomeDirectory()];
  
  // Present save panel as sheet
  [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
    if (result != NSModalResponseOK) {
      return;
    }
    
    NSURL *url = savePanel.URL;
    if (!url) {
      return;
    }
    
    // Capture the screenshot
    [self captureScreenshotToURL:url texture:texture];
  }];
}

- (void)captureScreenshotToURL:(NSURL *)url texture:(id<MTLTexture>)texture {
  NSUInteger width = texture.width;
  NSUInteger height = texture.height;
  
  // Calculate bytes per row (align to 256 bytes for Metal)
  size_t bytesPerRow = ((width * 4) + 255) & ~255;
  size_t bytesPerImage = bytesPerRow * height;
  
  id<MTLDevice> device = texture.device;
  if (!device) {
    NSLog(@"Cannot capture screenshot: no device available");
    return;
  }
  
  // Create readback buffer
  id<MTLBuffer> readback = [device newBufferWithLength:bytesPerImage options:MTLResourceStorageModeShared];
  if (!readback) {
    NSLog(@"Cannot capture screenshot: failed to allocate readback buffer");
    return;
  }
  
  // Create command buffer and blit encoder
  id<MTLCommandQueue> commandQueue = _renderer.commandQueue;
  if (!commandQueue) {
    NSLog(@"Cannot capture screenshot: no command queue available");
    return;
  }
  
  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
  id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
  
  // Copy texture to buffer
  [blit copyFromTexture:texture
            sourceSlice:0
            sourceLevel:0
           sourceOrigin:MTLOriginMake(0, 0, 0)
             sourceSize:MTLSizeMake(width, height, 1)
               toBuffer:readback
      destinationOffset:0
 destinationBytesPerRow:bytesPerRow
destinationBytesPerImage:bytesPerImage];
  
  [blit endEncoding];
  
  // Add completed handler to save the image
  [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
    if (buffer.status != MTLCommandBufferStatusCompleted) {
      NSLog(@"Screenshot GPU readback failed: %@", buffer.error);
      return;
    }
    
    const uint8_t *rawBytes = (const uint8_t *)readback.contents;
    if (!rawBytes) {
      NSLog(@"Screenshot readback buffer is not accessible");
      return;
    }
    
    // Create image data
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;
    
    CGContextRef context = CGBitmapContextCreate((void *)rawBytes, width, height, 8, bytesPerRow, colorSpace, bitmapInfo);
    if (!context) {
      NSLog(@"Failed to create bitmap context for screenshot");
      CGColorSpaceRelease(colorSpace);
      return;
    }
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    if (!cgImage) {
      NSLog(@"Failed to create CGImage for screenshot");
      return;
    }
    
    // Create PNG data
    NSMutableData *pngData = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)pngData, (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
    
    if (!dest) {
      NSLog(@"Failed to create PNG destination for screenshot");
      CGImageRelease(cgImage);
      return;
    }
    
    CGImageDestinationAddImage(dest, cgImage, NULL);
    BOOL success = CGImageDestinationFinalize(dest);
    
    CFRelease(dest);
    CGImageRelease(cgImage);
    
    if (!success) {
      NSLog(@"Failed to finalize PNG encoding for screenshot");
      return;
    }
    
    // Save to file
    NSError *error = nil;
    if (![pngData writeToURL:url options:NSDataWritingAtomic error:&error]) {
      NSLog(@"Failed to save screenshot: %@", error);
    } else {
      NSLog(@"Screenshot saved to: %@", url.path);
    }
  }];
  
  [commandBuffer commit];
}

#pragma mark - Configuration

- (BOOL)hasConfigureSheet {
  return YES;
}

- (NSWindow *)configureSheet {
  // Always create fresh panel to ensure shaders list is current
  // (previous panels might have been created before shader discovery)
  self.configPanel = nil;

  NSPanel *window = [[NSPanel alloc]
      initWithContentRect:NSMakeRect(0, 0, 320, 420)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setTitle:@"ShaderCandy Configuration"];
  self.configPanel = window;

  NSView *contentView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 420)];
  [window setContentView:contentView];
  
  // Debug log
  NSLog(@"MacOSMetalViewAdapter: configureSheet called, shaders: %@", _availableShaders);

  int y = 380;

  // Shader selector
  NSTextField *label =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [label setStringValue:@"Effect:"];
  [label setBezeled:NO];
  [label setDrawsBackground:NO];
  [label setEditable:NO];
  [contentView addSubview:label];

  NSPopUpButton *popup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(100, y - 2, 200, 25)
                                 pullsDown:NO];
  [popup addItemsWithTitles:_availableShaders ?: @[ @"default" ]];
  [popup selectItemWithTitle:_currentShaderName];
  [popup setTarget:self];
  [popup setAction:@selector(shaderSelected:)];
  [contentView addSubview:popup];

  y -= 40;

  // Speed slider
  NSTextField *speedLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [speedLabel setStringValue:@"Speed:"];
  [speedLabel setBezeled:NO];
  [speedLabel setDrawsBackground:NO];
  [speedLabel setEditable:NO];
  [contentView addSubview:speedLabel];

  NSSlider *speedSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  speedSlider.minValue = 0.1;
  speedSlider.maxValue = 3.0;
  speedSlider.floatValue = _speed;
  speedSlider.target = self;
  speedSlider.action = @selector(speedChanged:);
  [contentView addSubview:speedSlider];

  y -= 30;

  // Intensity slider
  NSTextField *intLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [intLabel setStringValue:@"Intensity:"];
  [intLabel setBezeled:NO];
  [intLabel setDrawsBackground:NO];
  [intLabel setEditable:NO];
  [contentView addSubview:intLabel];

  NSSlider *intSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  intSlider.minValue = 0.0;
  intSlider.maxValue = 2.0;
  intSlider.floatValue = _intensity;
  intSlider.target = self;
  intSlider.action = @selector(intensityChanged:);
  [contentView addSubview:intSlider];

  y -= 30;

  // Gravity slider
  NSTextField *gravLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 80, 20)];
  [gravLabel setStringValue:@"Gravity:"];
  [gravLabel setBezeled:NO];
  [gravLabel setDrawsBackground:NO];
  [gravLabel setEditable:NO];
  [contentView addSubview:gravLabel];

  NSSlider *gravSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  gravSlider.minValue = 0.1;
  gravSlider.maxValue = 5.0;
  gravSlider.floatValue = _gravity;
  gravSlider.target = self;
  gravSlider.action = @selector(gravityChanged:);
  [contentView addSubview:gravSlider];

  y -= 40;

  // Bloom toggle
  NSButton *bloomCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  [bloomCheck setButtonType:NSButtonTypeSwitch];
  [bloomCheck setTitle:@"Enable Bloom Glow"];
  [bloomCheck
      setState:_enableBloom ? NSControlStateValueOn : NSControlStateValueOff];
  [bloomCheck setTarget:self];
  [bloomCheck setAction:@selector(bloomChanged:)];
  [contentView addSubview:bloomCheck];

  y -= 30;

  // Metrics toggle
  NSButton *metricsCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  [metricsCheck setButtonType:NSButtonTypeSwitch];
  [metricsCheck setTitle:@"Show Performance Metrics"];
  // Use defaults if renderer not yet initialized
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  BOOL showMetrics = [defaults boolForKey:@"showMetrics"];
  if (_renderer && _renderer.showDebugOverlay) {
    showMetrics = _renderer.showDebugOverlay;
  }
  [metricsCheck setState:showMetrics ? NSControlStateValueOn : NSControlStateValueOff];
  [metricsCheck setTarget:self];
  [metricsCheck setAction:@selector(metricsChanged:)];
  [contentView addSubview:metricsCheck];

  y -= 30;

  // Auto-scaling toggle
  NSButton *autoScaleCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  [autoScaleCheck setButtonType:NSButtonTypeSwitch];
  [autoScaleCheck setTitle:@"Performance Auto-Scaling"];
  BOOL autoScaling = [defaults boolForKey:@"autoScaling"];
  if (_renderer && _renderer.autoScalingEnabled) {
    autoScaling = _renderer.autoScalingEnabled;
  }
  [autoScaleCheck setState:autoScaling ? NSControlStateValueOn : NSControlStateValueOff];
  [autoScaleCheck setTarget:self];
  [autoScaleCheck setAction:@selector(autoScaleChanged:)];
  [contentView addSubview:autoScaleCheck];

  y -= 30;

  // Soundscape toggle
  NSButton *soundCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  [soundCheck setButtonType:NSButtonTypeSwitch];
  [soundCheck setTitle:@"Atmospheric Soundscapes"];
  [soundCheck setState:[SoundscapeGenerator sharedGenerator].enabled
                           ? NSControlStateValueOn
                           : NSControlStateValueOff];
  [soundCheck setTarget:self];
  [soundCheck setAction:@selector(soundscapeChanged:)];
  [contentView addSubview:soundCheck];

  y -= 50;

  // OK button
  NSButton *okButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(220, 20, 80, 24)];
  [okButton setTitle:@"OK"];
  [okButton setBezelStyle:NSBezelStyleRounded];
  [okButton setAction:@selector(closeConfig:)];
  [okButton setTarget:self];
  [contentView addSubview:okButton];

  return window;
}

- (void)shaderSelected:(id)sender {
  NSPopUpButton *popup = (NSPopUpButton *)sender;
  NSString *name = [popup titleOfSelectedItem];
  if (name) {
    [self selectShaderNamed:name];
  }
}

- (void)speedChanged:(id)sender {
  _speed = [(NSSlider *)sender floatValue];
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setFloat:_speed forKey:@"speed"];
}

- (void)intensityChanged:(id)sender {
  _intensity = [(NSSlider *)sender floatValue];
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setFloat:_intensity forKey:@"intensity"];
}

- (void)gravityChanged:(id)sender {
  _gravity = [(NSSlider *)sender floatValue];
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setFloat:_gravity forKey:@"gravity"];
}

- (void)bloomChanged:(id)sender {
  _enableBloom = [(NSButton *)sender state] == NSControlStateValueOn;
  [_renderer setBloomEnabled:_enableBloom];
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setBool:_enableBloom forKey:@"enableBloom"];
}

- (void)metricsChanged:(id)sender {
  BOOL value = [(NSButton *)sender state] == NSControlStateValueOn;
  // Update renderer if available, otherwise just save to defaults
  if (_renderer) {
    _renderer.showDebugOverlay = value;
  }
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setBool:value forKey:@"showMetrics"];
}

- (void)autoScaleChanged:(id)sender {
  BOOL value = [(NSButton *)sender state] == NSControlStateValueOn;
  // Update renderer if available, otherwise just save to defaults
  if (_renderer) {
    _renderer.autoScalingEnabled = value;
  }
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setBool:value forKey:@"autoScaling"];
}

- (void)soundscapeChanged:(id)sender {
  [SoundscapeGenerator sharedGenerator].enabled =
      [(NSButton *)sender state] == NSControlStateValueOn;
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setBool:[SoundscapeGenerator sharedGenerator].enabled
             forKey:@"soundscape"];
}

- (void)closeConfig:(id)sender {
  // Save settings
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults synchronize];

  // Dismiss the config panel
  // For screensaver config sheets, the system handles dismissal automatically
  // after this method returns. Just release our reference.
  if (self.configPanel) {
    // Try to close as sheet first
    NSWindow *sheetParent = self.configPanel.sheetParent;
    if (sheetParent) {
      [sheetParent endSheet:self.configPanel returnCode:NSModalResponseOK];
    }
    [self.configPanel close];
    self.configPanel = nil;
  }
}

@end
