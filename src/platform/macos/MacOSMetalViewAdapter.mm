//
//  MacOSMetalViewAdapter.mm
//  ShaderCandy
//
//  Thin delegation layer implementation
//

#import "MacOSMetalViewAdapter.h"
#import "../../metal/MetalRenderer.h"

@interface MacOSMetalViewAdapter ()

@property(nonatomic, strong, nullable) MTKView *mtkView;
@property(nonatomic, strong, nullable) NSDate *startTime;
@property(nonatomic, assign) NSInteger frameCount;
@property(nonatomic, strong, nullable) NSWindow *configPanel;
@property(nonatomic, strong, nullable) NSString *currentShaderName;
@property(nonatomic, strong, nullable) NSArray<NSString *> *availableShaders;

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
  _enableBloom = YES;
  _speed = 1.0f;
  _intensity = 1.0f;
  _gravity = 1.0f;
  _preferredFPS = 60;
  _enableHotReload = NO;
  _frameCount = 0;

  NSLog(@"MacOSMetalViewAdapter: Initializing with frame %@",
        NSStringFromRect(self.bounds));
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  [self setupMetal];
}

- (void)setupMetal {
  if (self.mtkView)
    return;

  NSLog(@"MacOSMetalViewAdapter: Setting up Metal...");

  if (NSWidth(self.bounds) < 1.0 || NSHeight(self.bounds) < 1.0) {
    NSLog(@"MacOSMetalViewAdapter: Frame too small, deferring Metal setup");
    return;
  }

  // Create MTKView
  self.mtkView = [[MTKView alloc] initWithFrame:self.bounds device:nil];
  self.mtkView.delegate = self;
  self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  self.mtkView.depthStencilPixelFormat = MTLPixelFormatInvalid;
  self.mtkView.preferredFramesPerSecond = _preferredFPS;
  self.mtkView.enableSetNeedsDisplay = NO;
  self.mtkView.paused = NO;
  self.mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  [self addSubview:self.mtkView];

  // Create renderer
  NSError *error = nil;
  _renderer = [MetalRenderer rendererWithDevice:self.mtkView.device
                                          error:&error];
  if (error) {
    NSLog(@"MacOSMetalViewAdapter: Failed to create renderer: %@", error);
    return;
  }

  _renderer.developmentMode = _enableHotReload;
  _renderer.hotReloadEnabled = _enableHotReload;
  _renderer.preferredFPS = _preferredFPS;

  [_renderer setBloomEnabled:_enableBloom];
  [_renderer setViewportSize:self.mtkView.drawableSize];

  // Discover shaders
  _availableShaders = [_renderer availableShaderNames];
  NSLog(@"MacOSMetalViewAdapter: Found %lu shaders",
        (unsigned long)_availableShaders.count);

  // Load default shader
  if (_availableShaders.count > 0) {
    _currentShaderName = _availableShaders.firstObject;
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
  if (error) {
    NSLog(@"MacOSMetalViewAdapter: Failed to reload shader: %@", error);
  }
}

- (void)selectShaderNamed:(NSString *)name {
  if (![_availableShaders containsObject:name]) {
    NSLog(@"MacOSMetalViewAdapter: Unknown shader '%@'", name);
    return;
  }

  _currentShaderName = name;
  [self loadShaders];
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  [_renderer setViewportSize:size];
}

- (void)drawInMTKView:(MTKView *)view {
  if (!_renderer || !view.currentDrawable || !view.currentRenderPassDescriptor)
    return;

  // Get mouse position
  NSPoint mouseLocation = [NSEvent mouseLocation];
  NSRect frame = [self.window
      convertRectFromScreen:NSMakeRect(mouseLocation.x, mouseLocation.y, 0, 0)];

  // Update uniforms
  NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:_startTime];
  [_renderer updateUniformsWithTime:elapsed
                      mousePosition:frame.origin
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
  } else {
    [super keyDown:event];
  }
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
      initWithContentRect:NSMakeRect(0, 0, 320, 400)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setTitle:@"ShaderCandy Configuration"];
  [window setLevel:NSFloatingWindowLevel];
  [window setHidesOnDeactivate:YES];
  self.configPanel = window;

  NSView *contentView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 400)];
  [window setContentView:contentView];

  int y = 360;

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

  y -= 40;

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
  if (name && ![name isEqualToString:@"Cycle All"]) {
    [self selectShaderNamed:name];
  }
}

- (void)speedChanged:(id)sender {
  _speed = [(NSSlider *)sender floatValue];
}

- (void)intensityChanged:(id)sender {
  _intensity = [(NSSlider *)sender floatValue];
}

- (void)gravityChanged:(id)sender {
  _gravity = [(NSSlider *)sender floatValue];
}

- (void)bloomChanged:(id)sender {
  _enableBloom = [(NSButton *)sender state] == NSControlStateValueOn;
  [_renderer setBloomEnabled:_enableBloom];
}

- (void)metricsChanged:(id)sender {
  _renderer.showDebugOverlay =
      [(NSButton *)sender state] == NSControlStateValueOn;
}

- (void)autoScaleChanged:(id)sender {
  _renderer.autoScalingEnabled =
      [(NSButton *)sender state] == NSControlStateValueOn;
}

- (void)closeConfig:(id)sender {
  [self.configPanel orderOut:nil];
  self.configPanel = nil;
}

@end
