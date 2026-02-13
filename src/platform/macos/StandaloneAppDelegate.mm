//
//  StandaloneAppDelegate.mm
//  ShaderCandy
//
//  Standalone macOS Application Delegate for windowed preview
//

#import "StandaloneAppDelegate.h"
#import "../../config/ConfigurationManager.h"
#import "../../metal/MetalRenderer.h"
#import "../../metal/MetalSharedState.h"
#import "../../neural/NeuralStyleEngine.h"
#import "StandaloneAppWindowController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface StandaloneAppDelegate ()

// Private
@property(nonatomic, strong) NSMenu *appMenu;
@property(nonatomic, strong) NSMenu *fileMenu;
@property(nonatomic, strong) NSMenu *viewMenu;
@property(nonatomic, strong) NSMenu *settingsMenu;
@property(nonatomic, strong) NSMenu *helpMenu;
@property(nonatomic, assign) BOOL isRunning;
@property(nonatomic, strong) NSArray<NSString *> *availableShaders;

@end

@implementation StandaloneAppDelegate

#pragma mark - Application Lifecycle

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  // Initialize configuration
  [self initializeConfiguration];

  // Discover available shaders
  [self discoverAvailableShaders];

  // Set default values
  _speed = 1.0f;
  _intensity = 1.0f;
  _gravity = 1.0f;
  _currentShader = @"default";
  _isRunning = NO;

  // Initialize timing
  _startTime = [NSDate date];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  NSLog(@"applicationDidFinishLaunching started");

  // Create the main window
  [self createMainWindow];

  // Setup menu bar
  [self setupMenuBar];

  // Initialize Metal renderer
  NSLog(@"Initializing renderer...");
  if (![self initializeRenderer]) {
    NSLog(@"Failed to initialize Metal renderer");
    [NSApp terminate:nil];
    return;
  }
  NSLog(@"Renderer initialized successfully");

  // Now that renderer is initialized, discover available shaders from the
  // bundle
  NSLog(@"About to discover shaders...");
  [self discoverAvailableShaders];

  // Update window controller with discovered shaders
  NSLog(@"Setting %lu shaders on window controller",
        (unsigned long)_availableShaders.count);
  [_windowController setAvailableShaders:_availableShaders];

  // Load the initial shader
  [self loadInitialShader];

  // Start the render loop
  [self startRenderLoop];

  _isRunning = YES;

  NSLog(@"ShaderCandy Standalone App launched successfully");
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  // Stop the render loop
  [self stopRenderLoop];

  // Shutdown renderer
  [self shutdownRenderer];

  // Save configuration
  [self saveConfiguration];

  _isRunning = NO;

  NSLog(@"ShaderCandy Standalone App terminated");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

#pragma mark - Window Management

- (void)createMainWindow {
  // Always create window programmatically - skip nib file
  NSRect frame = NSMakeRect(0, 0, 1280, 720);
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setTitle:@"ShaderCandy"];
  [window setMinSize:NSMakeSize(640, 360)];

  // Create MTKView for Metal rendering
  MTKView *mtkView =
      [[MTKView alloc] initWithFrame:frame
                              device:MTLCreateSystemDefaultDevice()];
  mtkView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  mtkView.enableSetNeedsDisplay = YES;
  mtkView.paused = NO;
  mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
  mtkView.sampleCount = 1;

  [window.contentView addSubview:mtkView];
  _metalView = mtkView;

  // Create window controller with the programmatically created window
  _windowController =
      [[StandaloneAppWindowController alloc] initWithWindow:window];

  // Initialize all UI components manually
  [_windowController setupWindow];
  [_windowController setupToolbar];
  [_windowController setupShaderList];
  [_windowController setupMetricsDisplay];

  // Set available shaders for the window controller
  [_windowController setAvailableShaders:_availableShaders];

  // Set current shader if available
  if (_currentShader) {
    [_windowController selectShader:_currentShader];
  }

  // Set delegate
  _windowController.delegate = self;
  window.delegate = _windowController;

  // Center and show
  [window center];
  [window makeKeyAndOrderFront:nil];
  NSLog(@"Window shown: %@", window);

  // Center and show
  [window center];
  [window makeKeyAndOrderFront:nil];
}

- (NSWindow *)mainWindow {
  return _windowController.window;
}

#pragma mark - Menu Bar

- (void)setupMenuBar {
  NSMenu *menubar = [[NSMenu alloc] init];
  [NSApp setMainMenu:menubar];

  // App menu (ShaderCandy)
  _appMenu = [[NSMenu alloc] initWithTitle:@"ShaderCandy"];
  NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"ShaderCandy"
                                                       action:NULL
                                                keyEquivalent:@""];
  [appMenuItem setSubmenu:_appMenu];
  [menubar addItem:appMenuItem];

  // About ShaderCandy
  [_appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"About ShaderCandy"
                                               action:@selector(showAboutPanel)
                                        keyEquivalent:@""]];

  [_appMenu addItem:[NSMenuItem separatorItem]];

  // Preferences
  [_appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Preferences..."
                                               action:@selector(showPreferences)
                                        keyEquivalent:@","]];

  [_appMenu addItem:[NSMenuItem separatorItem]];

  // Services
  NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
  NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:@"Services"
                                                        action:NULL
                                                 keyEquivalent:@""];
  [servicesItem setSubmenu:servicesMenu];
  [_appMenu addItem:servicesItem];

  [_appMenu addItem:[NSMenuItem separatorItem]];

  // Hide/Show
  [_appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Hide ShaderCandy"
                                               action:@selector(hide:)
                                        keyEquivalent:@"h"]];

  [_appMenu addItem:[[NSMenuItem alloc]
                        initWithTitle:@"Hide Others"
                               action:@selector(hideOtherApplications:)
                        keyEquivalent:@"h"]];

  [_appMenu addItem:[[NSMenuItem alloc]
                        initWithTitle:@"Show All"
                               action:@selector(unhideAllApplications:)
                        keyEquivalent:@""]];

  [_appMenu addItem:[NSMenuItem separatorItem]];

  // Quit
  [_appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit ShaderCandy"
                                               action:@selector(terminate:)
                                        keyEquivalent:@"q"]];

  // File menu
  _fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
  NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"File"
                                                        action:NULL
                                                 keyEquivalent:@""];
  [fileMenuItem setSubmenu:_fileMenu];
  [menubar addItem:fileMenuItem];

  [_fileMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Open Shader..."
                                                action:@selector(openShaderFile)
                                         keyEquivalent:@"o"]];

  [_fileMenu addItem:[NSMenuItem separatorItem]];

  [_fileMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Export Preset..."
                                                action:@selector(exportPreset)
                                         keyEquivalent:@"e"]];

  [_fileMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Import Preset..."
                                                action:@selector(importPreset)
                                         keyEquivalent:@"i"]];

  // View menu
  _viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
  NSMenuItem *viewMenuItem = [[NSMenuItem alloc] initWithTitle:@"View"
                                                        action:NULL
                                                 keyEquivalent:@""];
  [viewMenuItem setSubmenu:_viewMenu];
  [menubar addItem:viewMenuItem];

  [_viewMenu
      addItem:[[NSMenuItem alloc] initWithTitle:@"Show Shader List"
                                         action:@selector(toggleShaderList)
                                  keyEquivalent:@"l"]];

  [_viewMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Show Metrics"
                                                action:@selector(toggleMetrics)
                                         keyEquivalent:@"m"]];

  [_viewMenu addItem:[NSMenuItem separatorItem]];

  [_viewMenu
      addItem:[[NSMenuItem alloc] initWithTitle:@"Enter Full Screen"
                                         action:@selector(toggleFullScreen)
                                  keyEquivalent:@"f"]];

  // Settings menu
  _settingsMenu = [[NSMenu alloc] initWithTitle:@"Settings"];
  NSMenuItem *settingsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Settings"
                                                            action:NULL
                                                     keyEquivalent:@""];
  [settingsMenuItem setSubmenu:_settingsMenu];
  [menubar addItem:settingsMenuItem];

  [_settingsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Speed"
                                                    action:NULL
                                             keyEquivalent:@""]];

  [_settingsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Intensity"
                                                    action:NULL
                                             keyEquivalent:@""]];

  [_settingsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Gravity"
                                                    action:NULL
                                             keyEquivalent:@""]];

  [_settingsMenu addItem:[NSMenuItem separatorItem]];

  [_settingsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Enable Bloom"
                                                    action:NULL
                                             keyEquivalent:@""]];

  [_settingsMenu
      addItem:[[NSMenuItem alloc] initWithTitle:@"Enable Audio Reactivity"
                                         action:NULL
                                  keyEquivalent:@""]];

  // Help menu
  _helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
  NSMenuItem *helpMenuItem = [[NSMenuItem alloc] initWithTitle:@"Help"
                                                        action:NULL
                                                 keyEquivalent:@""];
  [helpMenuItem setSubmenu:_helpMenu];
  [menubar addItem:helpMenuItem];

  [_helpMenu addItem:[[NSMenuItem alloc] initWithTitle:@"ShaderCandy Help"
                                                action:@selector(showHelp)
                                         keyEquivalent:@"?"]];

  [_helpMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Keyboard Shortcuts"
                                                action:@selector(showShortcuts)
                                         keyEquivalent:@""]];
}

#pragma mark - Renderer

- (BOOL)initializeRenderer {
  // Get the Metal device from the MTKView
  id<MTLDevice> device = _metalView.device;
  if (!device) {
    device = MTLCreateSystemDefaultDevice();
    if (!device) {
      NSLog(@"Metal is not supported on this system");
      return NO;
    }
    _metalView.device = device;
  }

  // Create error pointer
  NSError *error = nil;

  // Create the renderer
  _renderer = [MetalRenderer rendererWithDevice:device error:&error];
  if (!_renderer) {
    NSLog(@"Failed to create Metal renderer: %@", error.localizedDescription);
    return NO;
  }

  // Configure renderer
  _renderer.preferredFPS = 60;
  _renderer.developmentMode = NO;
  _renderer.hotReloadEnabled = YES;
  _renderer.autoScalingEnabled = YES;
  _renderer.autoScaleFPSThreshold = 45.0f;

  // Set the delegate
  _renderer.delegate = (id<MetalRendererDelegate>)_windowController;

  // Set up the MTKView delegate
  _metalView.delegate = (id<MTKViewDelegate>)self;

  return YES;
}

- (void)shutdownRenderer {
  if (_renderer) {
    [_renderer shutdown];
    _renderer = nil;
  }
}

- (void)loadInitialShader {
  if (!_renderer || !_currentShader)
    return;

  NSError *error = nil;
  BOOL success = [_renderer setActiveShader:_currentShader error:&error];
  if (!success) {
    NSLog(@"Failed to load initial shader '%@': %@", _currentShader,
          error.localizedDescription);
    // Fall back to default shader
    _currentShader = @"default";
    [_renderer setActiveShader:_currentShader error:nil];
  }
}

- (BOOL)switchToShader:(NSString *)shaderName {
  if (!_renderer)
    return NO;

  NSError *error = nil;
  BOOL success = [_renderer setActiveShader:shaderName error:&error];
  if (success) {
    _currentShader = shaderName;
    [_windowController onShaderSelected:shaderName];
    NSLog(@"Switched to shader: %@", shaderName);
  } else {
    NSLog(@"Failed to switch to shader '%@': %@", shaderName,
          error.localizedDescription);
  }

  return success;
}

#pragma mark - Shader Discovery

- (void)discoverAvailableShaders {
  NSLog(@"Discovering available shaders...");

  // Get shaders from the renderer
  if (_renderer) {
    NSLog(@"Renderer exists, querying availableShaderNames...");
    _availableShaders = [_renderer availableShaderNames];
    NSLog(@"Discovered %lu shaders from renderer",
          (unsigned long)_availableShaders.count);
  } else {
    NSLog(@"Renderer not available, using fallback shader list");
    // Fallback: return known shaders
    _availableShaders = @[
      @"default", @"mandelbulb_3d", @"julia_3d", @"julia_set",
      @"mandelbrot_set", @"nebula", @"vortex", @"ripples", @"tunnel", @"spiral",
      @"starfield_warp", @"neon_pulse", @"liquid_gradient",
      @"kaleidoscopic_tunnel", @"fractal_zoom"
    ];
  }
}

- (NSArray<NSString *> *)availableShaderNames {
  return _availableShaders ?: @[];
}

#pragma mark - Render Loop

- (void)startRenderLoop {
  // Start the display link if available
  if ([_metalView respondsToSelector:@selector(start)]) {
    [_metalView performSelector:@selector(start) withObject:nil afterDelay:0];
  }

  // Start update timer as fallback
  if (!_updateTimer) {
    _updateTimer =
        [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0
                                         target:self
                                       selector:@selector(updateTimerFired:)
                                       userInfo:nil
                                        repeats:YES];
  }
}

- (void)stopRenderLoop {
  [_updateTimer invalidate];
  _updateTimer = nil;

  if ([_metalView respondsToSelector:@selector(stop)]) {
    [_metalView performSelector:@selector(stop) withObject:nil];
  }
}

- (void)updateTimerFired:(NSTimer *)timer {
  // Force redraw
  [_metalView setNeedsDisplay:YES];
}

#pragma mark - StandaloneAppWindowControllerDelegate

- (void)windowController:(id)controller didSelectShader:(NSString *)shaderName {
  [self switchToShader:shaderName];
}

- (void)windowController:(id)controller
        didUpdateMetrics:(NSDictionary *)metrics {
  // Optional metrics update handling
}

- (void)windowController:(id)controller
       didEncounterError:(MetalRendererError *)error {
  // Already handled via renderer delegate in controller, but could add app-wide
  // error handling here
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  if (_renderer) {
    [_renderer setViewportSize:CGSizeMake(size.width, size.height)];
  }
}

- (void)drawInMTKView:(MTKView *)view {
  if (!_renderer)
    return;

  // Get the drawable
  id<CAMetalDrawable> drawable = view.currentDrawable;
  if (!drawable)
    return;

  // Update time for shader animation
  NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate] -
                        [_startTime timeIntervalSinceReferenceDate];

  // Update uniforms with current time and state
  NSPoint mousePos = [view.window mouseLocationOutsideOfEventStream];
  mousePos = [view convertPoint:mousePos fromView:nil];

  [_renderer updateUniformsWithTime:time
                      mousePosition:mousePos
                       mouseButtons:0
                              speed:_speed
                          intensity:_intensity
                            gravity:_gravity
                             height:view.bounds.size.height];

  // Sync renderer with global settings (Phase 5)
  auto &config = ShaderCandy::Config::ConfigurationManager::getInstance();
  const auto &settings = config.getSettings();
  _renderer.hdrEnabled = settings.hdr;
  _renderer.neuralStyleEnabled = settings.neuralStyleEnabled;
  _renderer.styleStrength = settings.neuralStyleStrength;
  if (settings.neuralStyleEnabled && settings.neuralStyleName.length() > 0) {
    [[NeuralStyleEngine sharedEngine]
        loadStyleNamed:[NSString stringWithUTF8String:settings.neuralStyleName
                                                          .c_str()]
                 error:nil];
  }

  // Begin frame
  [_renderer beginFrame];

  // Create render pass descriptor
  MTLRenderPassDescriptor *renderPassDescriptor =
      view.currentRenderPassDescriptor;
  if (!renderPassDescriptor)
    return;

  // Render
  [_renderer renderToDrawable:drawable
         renderPassDescriptor:renderPassDescriptor];

  // End frame
  [_renderer endFrame];
}

#pragma mark - Configuration

- (void)initializeConfiguration {
  // Load configuration from disk
  auto &config = ShaderCandy::Config::ConfigurationManager::getInstance();
  config.initialize();
  config.loadDefaults();
}

- (void)saveConfiguration {
  auto &config = ShaderCandy::Config::ConfigurationManager::getInstance();
  config.saveToFile(
      ShaderCandy::Config::ConfigurationManager::getConfigDirectory() +
      "/standalone.json");
}

#pragma mark - Menu Actions

- (void)showAboutPanel {
  NSString *appName = [[NSProcessInfo processInfo] processName];
  NSString *version = [[NSBundle mainBundle]
      objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  if (!version)
    version = @"1.0.0";

  NSString *aboutText = [NSString
      stringWithFormat:@"%@\nVersion %@\n\nShaderCandy is a cross-platform "
                       @"screensaver engine that renders real-time procedural "
                       @"graphics using native GPU APIs.\n\n© 2024 ShaderCandy",
                       appName, version];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = appName;
  alert.informativeText = aboutText;
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

- (void)showPreferences {
  // Post notification to show preferences
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowPreferences"
                                                      object:nil];
}

- (void)openShaderFile {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  openPanel.title = @"Open Shader";
  openPanel.allowsMultipleSelection = NO;
  openPanel.canChooseDirectories = NO;
  openPanel.allowedContentTypes = @[
    [UTType typeWithIdentifier:@"public.source-code"],
    [UTType typeWithIdentifier:@"public.text"]
  ];
  openPanel.directoryURL = [NSURL
      fileURLWithPath:[NSString stringWithUTF8String:
                                    ShaderCandy::Config::ConfigurationManager::
                                        getShaderDirectory()
                                            .c_str()]];

  if ([openPanel runModal] == NSModalResponseOK) {
    NSURL *selectedURL = openPanel.URL;
    NSString *shaderName =
        selectedURL.lastPathComponent.stringByDeletingPathExtension;
    [self switchToShader:shaderName];
  }
}

- (void)exportPreset {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ExportPreset"
                                                      object:nil];
}

- (void)importPreset {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  openPanel.title = @"Import Preset";
  openPanel.allowsMultipleSelection = YES;
  openPanel.canChooseDirectories = NO;
  openPanel.allowedContentTypes =
      @[ [UTType typeWithIdentifier:@"public.json"] ];

  if ([openPanel runModal] == NSModalResponseOK) {
    for (NSURL *url in openPanel.URLs) {
      // Import preset
      NSLog(@"Importing preset from: %@", url.path);
    }
  }
}

- (void)toggleShaderList {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleShaderList"
                                                      object:nil];
}

- (void)toggleMetrics {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ToggleMetrics"
                                                      object:nil];
}

- (void)toggleFullScreen {
  NSWindow *window = _windowController.window;
  if (window.styleMask & NSWindowStyleMaskFullScreen) {
    [window toggleFullScreen:nil];
  } else {
    [window toggleFullScreen:nil];
  }
}

- (void)showHelp {
  // Open documentation
  NSString *docsPath = [[NSBundle mainBundle] pathForResource:@"README"
                                                       ofType:@"md"];
  if (docsPath) {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:docsPath]];
  }
}

- (void)showShortcuts {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Keyboard Shortcuts";
  alert.informativeText =
      @"⌘L - Show Shader List\n⌘M - Show Metrics\n⌘F - Full Screen\n⌘, - "
      @"Preferences\n⌘Q - Quit\n\nShader Controls:\nSpace - Next Shader\n←/→ - "
      @"Previous/Next Shader\n↑/↓ - Speed +/-";
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

#pragma mark - Properties

- (void)setSpeed:(float)speed {
  _speed = speed;
  if (_renderer) {
    [_renderer updateUniformsWithTime:_renderer.metrics.currentFPS
                        mousePosition:NSMakePoint(0, 0)
                         mouseButtons:0
                                speed:speed
                            intensity:_intensity
                              gravity:_gravity
                               height:_metalView.bounds.size.height];
  }
}

- (void)setIntensity:(float)intensity {
  _intensity = intensity;
  if (_renderer) {
    [_renderer updateUniformsWithTime:_renderer.metrics.currentFPS
                        mousePosition:NSMakePoint(0, 0)
                         mouseButtons:0
                                speed:_speed
                            intensity:intensity
                              gravity:_gravity
                               height:_metalView.bounds.size.height];
  }
}

- (void)setGravity:(float)gravity {
  _gravity = gravity;
  if (_renderer) {
    [_renderer updateUniformsWithTime:_renderer.metrics.currentFPS
                        mousePosition:NSMakePoint(0, 0)
                         mouseButtons:0
                                speed:_speed
                            intensity:_intensity
                              gravity:gravity
                               height:_metalView.bounds.size.height];
  }
}

@end
