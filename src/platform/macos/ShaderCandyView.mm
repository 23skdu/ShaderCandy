//
//  ShaderCandyView.mm
//  ShaderCandy
//
//  macOS Screen Saver Implementation (Unified Thin Adapter)
//

#import "ShaderCandyView.h"
#import "../../metal/MetalRenderer.h"
#import <Foundation/Foundation.h>

@interface ShaderCandyView ()

@property(nonatomic, strong, readwrite, nullable) MetalRenderer *renderer;
@property(nonatomic, strong, nullable) MTKView *mtkView;
@property(nonatomic, strong, nullable) NSDate *startTime;
@property(nonatomic, assign) NSInteger frameCount;

// Cycling
@property(nonatomic, assign) BOOL isCycling;
@property(nonatomic, assign) NSTimeInterval cycleInterval;
@property(nonatomic, strong, nullable) NSDate *lastCycleTime;

@end

@implementation ShaderCandyView

#pragma mark - Initialization

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
  _frameCount = 0;
  _startTime = [NSDate date];
  _isCycling = NO;
  _cycleInterval = 10.0;

  // Load Defaults
  ScreenSaverDefaults *defaults = [ScreenSaverDefaults
      defaultsForModuleWithName:@"com.shadercandy.screensaver"];
  [defaults registerDefaults:@{
    @"selectedShader" : @"Cycle All",
    @"preferredFPS" : @60,
    @"enableBloom" : @YES,
    @"speed" : @1.0,
    @"intensity" : @1.0,
    @"gravity" : @1.0,
    @"hotReload" : @YES
  }];

  _preferredFPS = [defaults integerForKey:@"preferredFPS"];
  _enableBloom = [defaults boolForKey:@"enableBloom"];
  _speed = [defaults floatForKey:@"speed"];
  _intensity = [defaults floatForKey:@"intensity"];
  _gravity = [defaults floatForKey:@"gravity"];
  _enableHotReload = [defaults boolForKey:@"hotReload"];
  _currentShaderName = [defaults stringForKey:@"selectedShader"];

  self.animationTimeInterval = 1.0 / (double)_preferredFPS;
}

#pragma mark - Lifecycle

- (void)startAnimation {
  [super startAnimation];

  // macOS 15 Tahoe Fix: Ensure zero bounds are recovered
  if (NSWidth(self.bounds) < 1.0) {
    NSScreen *screen = self.window.screen ?: [NSScreen mainScreen];
    [self setFrame:screen.frame];
  }

  if (!_mtkView) {
    [self setupMetal];
  }
}

- (void)stopAnimation {
  [super stopAnimation];
}

- (void)setFrame:(NSRect)frame {
  [super setFrame:frame];
  if (_mtkView)
    _mtkView.frame = self.bounds;
}

- (void)setupMetal {
  if (NSWidth(self.bounds) < 1.0 || NSHeight(self.bounds) < 1.0)
    return;

  _mtkView = [[MTKView alloc] initWithFrame:self.bounds device:nil];
  _mtkView.delegate = self;
  _mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  _mtkView.preferredFramesPerSecond = _preferredFPS;
  _mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [self addSubview:_mtkView];

  NSError *error = nil;
  _renderer = [MetalRenderer rendererWithDevice:_mtkView.device error:&error];
  if (!_renderer) {
    NSLog(@"ShaderCandyView: Failed to create renderer: %@", error);
    return;
  }

  _renderer.hotReloadEnabled = _enableHotReload;
  _renderer.developmentMode = _enableHotReload;
  [_renderer setBloomEnabled:_enableBloom];
  [_renderer setViewportSize:self.bounds.size];

  _availableShaders = [_renderer availableShaderNames];

  if ([_currentShaderName isEqualToString:@"Cycle All"]) {
    if (_availableShaders.count > 0) {
      _isCycling = YES;
      _currentShaderName = _availableShaders.firstObject;
      _lastCycleTime = [NSDate date];
    } else {
      _isCycling = NO;
      NSLog(@"ShaderCandyView: No shaders available for cycling");
    }
  }

  [self loadShaders];
}

- (void)loadShaders {
  if (!_renderer || !_currentShaderName)
    return;
  NSError *error = nil;
  [_renderer setActiveShader:_currentShaderName error:&error];
}

- (void)animateOneFrame {
  if (_isCycling) {
    NSTimeInterval elapsed =
        [[NSDate date] timeIntervalSinceDate:_lastCycleTime];
    if (elapsed > _cycleInterval) {
      [self cycleToNextShader];
    }
  }
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

  NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:_startTime];
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

#pragma mark - Configuration

- (BOOL)hasConfigureSheet {
  return YES;
}

- (NSWindow *)configureSheet {
  if (self.configPanel)
    return self.configPanel;

  // Simple direct implementation for the config sheet to keep the file small
  // In a real app we'd load a XIB or use a more robust UI builder
  NSPanel *panel = [[NSPanel alloc]
      initWithContentRect:NSMakeRect(0, 0, 320, 240)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [panel setTitle:@"ShaderCandy"];
  self.configPanel = panel;

  NSView *cv = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 240)];
  [panel setContentView:cv];

  // Just a placeholder "OK" button for the example, detailed UI usually moved
  // to a separate controller
  NSButton *ok = [[NSButton alloc] initWithFrame:NSMakeRect(120, 20, 80, 24)];
  [ok setTitle:@"OK"];
  [ok setAction:@selector(closeConfig:)];
  [ok setTarget:self];
  [cv addSubview:ok];

  return panel;
}

- (void)closeConfig:(id)sender {
  if (self.configPanel) {
    [self.window endSheet:self.configPanel];
    self.configPanel = nil;
  }
}

@end
