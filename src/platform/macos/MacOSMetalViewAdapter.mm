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
@property(nonatomic, strong, nullable) NSWindow *configPanel;
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
}

- (void)setFrame:(NSRect)frame {
  [super setFrame:frame];
  if (_mtkView) {
    _mtkView.frame = self.bounds;
  }
}

- (void)startAnimation {
  [super startAnimation];

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
  if (!self.mtkView) {
    [self setupMetal];
  }
}

- (void)setupMetal {
  if (self.mtkView)
    return;

  // We allow small frames for isPreview, but not zero.
  if (NSWidth(self.bounds) < 1.0 || NSHeight(self.bounds) < 1.0) {
    NSLog(@"MacOSMetalViewAdapter: Frame too small (%@), deferring Metal setup",
          NSStringFromRect(self.bounds));
    return;
  }

  NSLog(@"MacOSMetalViewAdapter: Setting up Metal for %@ view...",
        self.isPreview ? @"preview" : @"main");

  // Create MTKView
  self.mtkView = [[MTKView alloc] initWithFrame:self.bounds device:nil];
  self.mtkView.delegate = self;
  self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  self.mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
  self.mtkView.preferredFramesPerSecond = _preferredFPS;
  self.mtkView.enableSetNeedsDisplay = NO; // Driven by display link
  self.mtkView.paused = NO;
  self.mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

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

  // Discover shaders
  _availableShaders = [_renderer availableShaderNames];

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

  self.mtkView.device = _renderer.device;
  _startTime = [NSDate date];

  NSLog(@"MacOSMetalViewAdapter: Metal setup complete");
}

- (void)loadShaders {
  if (!_renderer || !_currentShaderName)
    return;

  NSError *error = nil;
  [_renderer setActiveShader:_currentShaderName error:&error];
  if (error) {
    NSLog(@"MacOSMetalViewAdapter: Failed to load shader '%@': %@",
          _currentShaderName, error);
  }
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
  if (!_renderer || !view.currentDrawable || !view.currentRenderPassDescriptor)
    return;

  // Update uniforms
  NSTimeInterval elapsed = [[MetalSharedState sharedState] synchronizedTime];

  // Get mouse position relative to window
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

  // Render
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
    _renderer.showDebugOverlay = !_renderer.showDebugOverlay;
    // Save state
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults
        defaultsForModuleWithName:@"com.shadercandy.screensaver"];
    [defaults setBool:_renderer.showDebugOverlay forKey:@"showMetrics"];
    [defaults synchronize];
  } else if ([chars isEqualToString:@"s"] || [chars isEqualToString:@"S"]) {
    // Screenshot shortcut for screensaver
    [self saveScreenshot];
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
  if (self.configPanel) {
    return self.configPanel;
  }

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
  [metricsCheck setState:_renderer.showDebugOverlay ? NSControlStateValueOn
                                                    : NSControlStateValueOff];
  [metricsCheck setTarget:self];
  [metricsCheck setAction:@selector(metricsChanged:)];
  [contentView addSubview:metricsCheck];

  y -= 30;

  // Auto-scaling toggle
  NSButton *autoScaleCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  [autoScaleCheck setButtonType:NSButtonTypeSwitch];
  [autoScaleCheck setTitle:@"Performance Auto-Scaling"];
  [autoScaleCheck setState:_renderer.autoScalingEnabled
                               ? NSControlStateValueOn
                               : NSControlStateValueOff];
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
  _renderer.showDebugOverlay =
      [(NSButton *)sender state] == NSControlStateValueOn;
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setBool:_renderer.showDebugOverlay forKey:@"showMetrics"];
}

- (void)autoScaleChanged:(id)sender {
  _renderer.autoScalingEnabled =
      [(NSButton *)sender state] == NSControlStateValueOn;
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults setBool:_renderer.autoScalingEnabled forKey:@"autoScaling"];
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
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults synchronize];

  if (self.configPanel) {
    [self.configPanel orderOut:nil];
    self.configPanel = nil;
  }
}

@end
