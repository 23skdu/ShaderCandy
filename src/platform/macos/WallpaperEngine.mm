//
//  WallpaperEngine.mm
//  ShaderCandy
//
//  Engine for managing ShaderCandy as a desktop wallpaper
//

#import "WallpaperEngine.h"
#import "DesktopView.h"
#import "../../metal/MetalRenderer.h"
#import "../../metal/MetalSharedState.h"
#import "../../core/MultiDisplayManager.h"
#import <Carbon/Carbon.h>
#import < Quartz/Quartz.h>
#import < QuartzCore/CoreAnimation.h>

NSString * const WallpaperEngineDidStartNotification = @"WallpaperEngineDidStart";
NSString * const WallpaperEngineDidStopNotification = @"WallpaperEngineDidStop";
NSString * const WallpaperEngineDidChangeShaderNotification = @"WallpaperEngineDidChangeShader";
NSString * const WallpaperEngineDidEncounterErrorNotification = @"WallpaperEngineDidEncounterError";

@interface WallpaperEngine ()

// Display management
@property(nonatomic, strong) NSMutableDictionary<NSString *, DesktopView *> *desktopViews;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *desktopShaders;
@property(nonatomic, strong) NSMutableArray<NSString *> *displayIDs;

// Rendering
@property(nonatomic, strong, nullable) MetalRenderer *renderer;
@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) id<MTLCommandQueue> commandQueue;

// State
@property(nonatomic, assign) BOOL isRunning;
@property(nonatomic, assign) BOOL isPaused;
@property(nonatomic, assign) BOOL wasPausedForBattery;
@property(nonatomic, strong, nullable) NSString *pendingShaderChange;

// Notifications
@property(nonatomic, strong) id screenSleepObserver;
@property(nonatomic, strong) id screenWakeObserver;
@property(nonatomic, strong) id spaceChangeObserver;

// Shader rotation
@property(nonatomic, strong, nullable) NSTimer *shaderRotationTimer;
@property(nonatomic, assign) NSInteger shaderRotationIndex;

@end

@implementation WallpaperEngine

#pragma mark - Singleton

+ (instancetype)sharedEngine {
    static WallpaperEngine *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WallpaperEngine alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _desktopViews = [NSMutableDictionary dictionary];
        _desktopShaders = [NSMutableDictionary dictionary];
        _displayIDs = [NSMutableArray array];
        _isRunning = NO;
        _isPaused = NO;
        _startAtLogin = NO;
        _pauseOnBattery = YES;
        _pauseOnScreenLock = YES;
        _enableAudio = NO;
        _shaderRotationIndex = 0;
        
        [self setupNotifications];
        [self enumerateDisplays];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    [self removeNotifications];
}

#pragma mark - Setup

- (void)setupNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // Screen sleep/wake
    _screenSleepObserver = [nc addObserverForName:NSWorkspaceScreensDidSleepNotification
                                            object:nil
                                             queue:[NSOperationQueue mainQueue]
                                        usingBlock:^(NSNotification *note) {
        [self handleScreenSleep];
    }];
    
    _screenWakeObserver = [nc addObserverForName:NSWorkspaceScreensDidWakeNotification
                                           object:nil
                                            queue:[NSOperationQueue mainQueue]
                                       usingBlock:^(NSNotification *note) {
        [self handleScreenWake];
    }];
    
    // Power notifications
    [nc addObserver:self
           selector:@selector(powerStateDidChange:)
               name:NSWorkspacePowerStateDidChangeNotification
             object:nil];
    
    // Active space change
    [nc addObserver:self
           selector:@selector(spaceDidChange:)
               name:NSWorkspaceActiveSpaceDidChangeNotification
             object:nil];
}

- (void)removeNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    if (_screenSleepObserver) {
        [nc removeObserver:_screenSleepObserver];
        _screenSleepObserver = nil;
    }
    
    if (_screenWakeObserver) {
        [nc removeObserver:_screenWakeObserver];
        _screenWakeObserver = nil;
    }
    
    [nc removeObserver:self];
}

- (void)enumerateDisplays {
    [_displayIDs removeAllObjects];
    
    NSArray *screens = [NSScreen screens];
    for (NSUInteger i = 0; i < screens.count; i++) {
        NSScreen *screen = screens[i];
        NSString *displayID = [NSString stringWithFormat:@"Display%lu", (unsigned long)(i + 1)];
        [_displayIDs addObject:displayID];
        
        // Set default shader if not already set
        if (!_desktopShaders[displayID]) {
            _desktopShaders[displayID] = @"plasma";
        }
    }
}

#pragma mark - Control

- (BOOL)start {
    if (_isRunning) {
        return YES;
    }
    
    // Get Metal device
    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        NSLog(@"Metal not available");
        [self postError:@"Metal is not supported on this Mac"];
        return NO;
    }
    
    // Create command queue
    _commandQueue = [_device newCommandQueue];
    
    // Create renderer
    NSError *error = nil;
    _renderer = [MetalRenderer rendererWithDevice:_device error:&error];
    if (!_renderer) {
        NSLog(@"Failed to create renderer: %@", error);
        [self postError:error.localizedDescription];
        return NO;
    }
    
    // Configure renderer for wallpaper mode
    _renderer.preferredFPS = 30;  // Lower FPS for wallpaper
    _renderer.autoScalingEnabled = YES;
    _renderer.autoScaleFPSThreshold = 20.0f;
    
    // Create desktop views for each display
    [self createDesktopViews];
    
    // Start rendering
    _isRunning = YES;
    _isPaused = NO;
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:WallpaperEngineDidStartNotification
                                                        object:self];
    
    NSLog(@"Wallpaper engine started");
    return YES;
}

- (void)stop {
    if (!_isRunning) {
        return;
    }
    
    // Stop shader rotation
    [_shaderRotationTimer invalidate];
    _shaderRotationTimer = nil;
    
    // Stop all desktop views
    for (DesktopView *view in _desktopViews.allValues) {
        [view stopRendering];
    }
    
    // Shutdown renderer
    [_renderer shutdown];
    _renderer = nil;
    _commandQueue = nil;
    
    // Clear desktop views
    for (DesktopView *view in _desktopViews.allValues) {
        [view removeFromSuperview];
    }
    [_desktopViews removeAllObjects];
    
    _isRunning = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WallpaperEngineDidStopNotification
                                                        object:self];
    
    NSLog(@"Wallpaper engine stopped");
}

- (void)pause {
    if (!_isRunning || _isPaused) return;
    
    _isPaused = YES;
    
    for (DesktopView *view in _desktopViews.allValues) {
        [view pauseRendering];
    }
    
    NSLog(@"Wallpaper engine paused");
}

- (void)resume {
    if (!_isRunning || !_isPaused) return;
    
    _isPaused = NO;
    
    for (DesktopView *view in _desktopViews.allValues) {
        [view resumeRendering];
    }
    
    NSLog(@"Wallpaper engine resumed");
}

#pragma mark - Desktop Views

- (void)createDesktopViews {
    NSArray *screens = [NSScreen screens];
    
    for (NSUInteger i = 0; i < screens.count; i++) {
        NSScreen *screen = screens[i];
        NSString *displayID = _displayIDs[i];
        
        // Create borderless, transparent window for wallpaper
        NSRect frame = screen.frame;
        NSWindow *wallpaperWindow = [[NSWindow alloc] initWithContentRect:frame
                                                                styleMask:NSWindowStyleMaskBorderless
                                                                  backing:NSBackingStoreBuffered
                                                                    defer:NO
                                                                   screen:screen];
        
        wallpaperWindow.level = CGWindowLevelForKey(kCGWindowLevelKeyDesktop);
        wallpaperWindow.ignoresMouseEvents = YES;
        wallpaperWindow.acceptsMouseMovedEvents = NO;
        wallpaperWindow.movableByWindowBackground = NO;
        wallpaperWindow.hasShadow = NO;
        wallpaperWindow.opaque = NO;
        wallpaperWindow.backgroundColor = [NSColor clearColor];
        
        // Create DesktopView
        DesktopView *desktopView = [[DesktopView alloc] initWithFrame:frame
                                                              displayID:displayID
                                                                 device:_device];
        desktopView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        wallpaperWindow.contentView = desktopView;
        _desktopViews[displayID] = desktopView;
        
        [wallpaperWindow orderBack:nil];
        [wallpaperWindow makeKeyAndOrderFront:nil];
        
        // Set initial shader
        NSString *shaderName = _desktopShaders[displayID] ?: @"plasma";
        [desktopView setShader:shaderName renderer:_renderer];
    }
}

#pragma mark - Wallpaper Management

- (BOOL)setWallpaperForDesktop:(NSString *)desktopID withShader:(NSString *)shaderName {
    if (!_desktopViews[desktopID]) {
        NSLog(@"Unknown desktop: %@", desktopID);
        return NO;
    }
    
    _desktopShaders[desktopID] = shaderName;
    
    DesktopView *view = _desktopViews[desktopID];
    [view setShader:shaderName renderer:_renderer];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WallpaperEngineDidChangeShaderNotification
                                                        object:self
                                                      userInfo:@{@"desktop": desktopID, @"shader": shaderName}];
    
    return YES;
}

- (BOOL)setWallpaperForAllDesktops:(NSString *)shaderName {
    BOOL success = YES;
    
    for (NSString *displayID in _displayIDs) {
        if (![self setWallpaperForDesktop:displayID withShader:shaderName]) {
            success = NO;
        }
    }
    
    return success;
}

- (BOOL)setWallpaperForCurrentSpace:(NSString *)shaderName {
    // Get current space's primary display
    NSString *primaryDisplay = [self primaryDisplayID];
    return [self setWallpaperForDesktop:primaryDisplay withShader:shaderName];
}

- (void)clearWallpaper {
    for (NSString *displayID in _displayIDs) {
        [self clearWallpaperForDesktop:displayID];
    }
}

- (void)clearWallpaperForDesktop:(NSString *)desktopID {
    DesktopView *view = _desktopViews[desktopID];
    if (view) {
        [view setShader:nil renderer:nil];
    }
    _desktopShaders[desktopID] = nil;
}

#pragma mark - Shader Management

- (void)switchToShader:(NSString *)shaderName {
    if (_isPaused) {
        _pendingShaderChange = shaderName;
        return;
    }
    
    for (NSString *displayID in _displayIDs) {
        [self setWallpaperForDesktop:displayID withShader:shaderName];
    }
}

- (void)nextShader {
    // Cycle through available shaders
    NSArray *shaders = @[@"plasma", @"mandelbulb_3d", @"nebula", @"vortex", @"tunnel"];
    _shaderRotationIndex = (_shaderRotationIndex + 1) % shaders.count;
    [self switchToShader:shaders[_shaderRotationIndex]];
}

- (void)previousShader {
    NSArray *shaders = @[@"plasma", @"mandelbulb_3d", @"nebula", @"vortex", @"tunnel"];
    _shaderRotationIndex = (_shaderRotationIndex - 1 + shaders.count) % shaders.count;
    [self switchToShader:shaders[_shaderRotationIndex]];
}

#pragma mark - Shader Rotation

- (void)startShaderRotation:(NSTimeInterval)interval {
    [_shaderRotationTimer invalidate];
    
    _shaderRotationTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                             target:self
                                                           selector:@selector(rotateShader)
                                                           userInfo:nil
                                                            repeats:YES];
}

- (void)stopShaderRotation {
    [_shaderRotationTimer invalidate];
    _shaderRotationTimer = nil;
}

- (void)rotateShader {
    [self nextShader];
}

#pragma mark - Display Configuration

- (NSString *)primaryDisplayID {
    if (_displayIDs.count > 0) {
        return _displayIDs[0];
    }
    return @"Display1";
}

- (NSString *)displayIDForWindow:(NSWindow *)window {
    NSScreen *screen = window.screen;
    NSUInteger index = [[NSScreen screens] indexOfObject:screen];
    if (index != NSNotFound && index < _displayIDs.count) {
        return _displayIDs[index];
    }
    return [self primaryDisplayID];
}

- (CGDirectDisplayID)cgDisplayIDForDesktopID:(NSString *)desktopID {
    NSUInteger index = [_displayIDs indexOfObject:desktopID];
    if (index != NSNotFound && index < [NSScreen screens].count) {
        NSScreen *screen = [NSScreen screens][index];
        return (CGDirectDisplayID)screen.deviceDescription[@"NSScreenNumber"];
    }
    return kCGNullDirectDisplayID;
}

#pragma mark - Lifecycle Handlers

- (void)handleScreenSleep {
    NSLog(@"Wallpaper: Screen going to sleep");
    [self pause];
}

- (void)handleScreenWake {
    NSLog(@"Wallpaper: Screen woke up");
    
    // Resume if not paused for battery
    if (!_wasPausedForBattery) {
        [self resume];
    }
}

- (void)handleSpaceChange {
    NSLog(@"Wallpaper: Space changed");
    // Could update shader for new space here
}

- (void)powerStateDidChange:(NSNotification *)notification {
    // Check if on battery
    BOOL onBattery = [self isOnBattery];
    
    if (_pauseOnBattery && onBattery && _isRunning && !_isPaused) {
        _wasPausedForBattery = YES;
        [self pause];
    } else if (_wasPausedForBattery && !onBattery) {
        _wasPausedForBattery = NO;
        [self resume];
    }
}

- (BOOL)isOnBattery {
    // Check using IOPowerSources
    CFTypeRef powerInfo = IOPSCopyPowerSourcesInfo();
    if (!powerInfo) return NO;
    
    CFArrayRef powerSources = IOPSCopyPowerSourcesList(powerInfo);
    if (!powerSources) {
        CFRelease(powerInfo);
        return NO;
    }
    
    BOOL onBattery = NO;
    for (NSUInteger i = 0; i < CFArrayGetCount(powerSources); i++) {
        CFTypeRef powerSource = CFArrayGetValueAtIndex(powerSources, i);
        NSDictionary *description = (__bridge NSDictionary *)IOPSGetPowerSourceDescription(powerInfo, powerSource);
        
        if ([description[@"Type"] isEqualToString:@"InternalBattery"]) {
            onBattery = YES;
            break;
        }
    }
    
    CFRelease(powerSources);
    CFRelease(powerInfo);
    
    return onBattery;
}

- (void)spaceDidChange:(NSNotification *)notification {
    [self handleSpaceChange];
}

#pragma mark - Properties

- (NSInteger)displayCount {
    return _displayIDs.count;
}

- (NSArray<NSString *> *)displayIDs {
    return [_displayIDs copy];
}

- (BOOL)isActive {
    return _isRunning && !_isPaused;
}

#pragma mark - Error Handling

- (void)postError:(NSString *)message {
    [[NSNotificationCenter defaultCenter] postNotificationName:WallpaperEngineDidEncounterErrorNotification
                                                        object:self
                                                      userInfo:@{@"error": message}];
}

@end
