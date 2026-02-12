//
//  StandaloneAppWindowController.mm
//  ShaderCandy
//
//  Window controller for the standalone player application
//

#import "StandaloneAppWindowController.h"
#import "PreferencesWindowController.h"
#import "ShadersListViewController.h"
#import "../../metal/MetalRenderer.h"
#import "../../metal/MetalSharedState.h"
#import "../../audio/SoundscapeGenerator.h"

@interface StandaloneAppWindowController () <MetalRendererDelegate, NSToolbarDelegate>

// Toolbar
@property(nonatomic, strong) NSToolbar *toolbar;
@property(nonatomic, strong) NSToolbarItem *shaderSelectorItem;
@property(nonatomic, strong) NSToolbarItem *previousItem;
@property(nonatomic, strong) NSToolbarItem *nextItem;
@property(nonatomic, strong) NSToolbarItem *fullScreenItem;

// Child view controllers
@property(nonatomic, strong) ShadersListViewController *shadersListVC;

// Metrics
@property(nonatomic, assign) double currentFPS;
@property(nonatomic, assign) double gpuTime;
@property(nonatomic, assign) NSInteger droppedFrames;

// Time tracking
@property(nonatomic, strong) NSDate *startTime;
@property(nonatomic, assign) NSTimeInterval shaderStartTime;

@end

@implementation StandaloneAppWindowController

#pragma mark - Initialization

- (instancetype)initWithWindow:(NSWindow *)window {
    self = [super initWithWindow:window];
    if (self) {
        _availableShaders = @[];
        _currentShaderIndex = 0;
        _showingShaderList = NO;
        _showingMetrics = NO;
        _startTime = [NSDate date];
        _shaderStartTime = 0;
        
        [self setupWindow];
        [self setupToolbar];
    }
    return self;
}

- (instancetype)initWithWindowNibName:(NSString *)nibName {
    self = [super initWithWindowNibName:nibName];
    if (self) {
        _availableShaders = @[];
        _currentShaderIndex = 0;
        _showingShaderList = NO;
        _showingMetrics = NO;
        _startTime = [NSDate date];
        _shaderStartTime = 0;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    if (self.window) {
        [self setupWindow];
        [self setupToolbar];
        [self setupShaderList];
        [self setupMetricsDisplay];
    }
}

#pragma mark - Window Setup

- (void)setupWindow {
    if (!self.window) return;
    
    // Set window delegate
    self.window.delegate = self;
    
    // Configure content view
    NSView *contentView = self.window.contentView;
    
    // Create Metal view if not already present
    if (!_metalView) {
        NSRect frame = contentView.bounds;
        _metalView = [[MTKView alloc] initWithFrame:frame device:MTLCreateSystemDefaultDevice()];
        _metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _metalView.enableSetNeedsDisplay = YES;
        _metalView.paused = NO;
        _metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        _metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        _metalView.sampleCount = 1;
        _metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        
        [contentView addSubview:_metalView];
    }
    
    // Create shader name label
    if (!_shaderNameLabel) {
        _shaderNameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, contentView.bounds.size.height - 40, 300, 24)];
        _shaderNameLabel.stringValue = @"ShaderCandy";
        _shaderNameLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
        _shaderNameLabel.textColor = [NSColor whiteColor];
        _shaderNameLabel.backgroundColor = [NSColor colorWithWhite:0 alpha:0.5];
        _shaderNameLabel.bordered = NO;
        _shaderNameLabel.editable = NO;
        _shaderNameLabel.bezeled = NO;
        _shaderNameLabel.selectable = NO;
        _shaderNameLabel.autoresizingMask = NSViewMinYMargin | NSViewMaxXMargin;
        
        [contentView addSubview:_shaderNameLabel];
    }
}

#pragma mark - Toolbar Setup

- (void)setupToolbar {
    _toolbar = [[NSToolbar alloc] initWithIdentifier:@"ShaderCandyToolbar"];
    _toolbar.delegate = self;
    _toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    _toolbar.sizeMode = NSToolbarSizeModeRegular;
    _toolbar.allowsUserCustomization = NO;
    _toolbar.autosavesConfiguration = NO;
    
    if (self.window) {
        self.window.toolbar = _toolbar;
    }
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    
    if ([itemIdentifier isEqualToString:@"shaderSelector"]) {
        _shaderSelectorItem = item;
        item.label = @"Shader";
        item.paletteLabel = @"Shader Selector";
        item.toolTip = @"Select current shader";
        
        NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 150, 24)];
        popup.action = @selector(shaderPopupSelected:);
        popup.target = self;
        item.view = popup;
        
    } else if ([itemIdentifier isEqualToString:@"previous"]) {
        _previousItem = item;
        item.label = @"Previous";
        item.paletteLabel = @"Previous Shader";
        item.toolTip = @"Go to previous shader";
        item.image = [NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Previous"];
        item.action = @selector(previousShader);
        
    } else if ([itemIdentifier isEqualToString:@"next"]) {
        _nextItem = item;
        item.label = @"Next";
        item.paletteLabel = @"Next Shader";
        item.toolTip = @"Go to next shader";
        item.image = [NSImage imageWithSystemSymbolName:@"chevron.right" accessibilityDescription:@"Next"];
        item.action = @selector(nextShader);
        
    } else if ([itemIdentifier isEqualToString:@"fullscreen"]) {
        _fullScreenItem = item;
        item.label = @"Full Screen";
        item.paletteLabel = @"Full Screen";
        item.toolTip = @"Enter full screen mode";
        item.image = [NSImage imageWithSystemSymbolName:@"arrow.up.left.and.arrow.down.right" accessibilityDescription:@"Full Screen"];
        item.action = @selector(toggleFullScreen);
        
    } else if ([itemIdentifier isEqualToString:@"shadersList"]) {
        item.label = @"Shaders";
        item.paletteLabel = @"Shader List";
        item.toolTip = @"Show shader list";
        item.image = [NSImage imageWithSystemSymbolName:@"square.grid.2x2" accessibilityDescription:@"Shaders"];
        item.action = @selector(showShadersList);
        
    } else if ([itemIdentifier isEqualToString:@"metrics"]) {
        item.label = @"Metrics";
        item.paletteLabel = @"Performance Metrics";
        item.toolTip = @"Show performance metrics";
        item.image = [NSImage imageWithSystemSymbolName:@"chart.bar" accessibilityDescription:@"Metrics"];
        item.action = @selector(toggleMetrics);
        
    } else if ([itemIdentifier isEqualToString:@"settings"]) {
        item.label = @"Settings";
        item.paletteLabel = @"Settings";
        item.toolTip = @"Open preferences";
        item.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"];
        item.action = @selector(showSettings);
        
    } else {
        return nil;
    }
    
    return item;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[@"shaderSelector", NSToolbarFlexibleSpaceItemIdentifier, @"previous", @"next", NSToolbarFlexibleSpaceItemIdentifier, @"shadersList", @"metrics", @"settings", @"fullScreen"];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[@"shaderSelector", @"previous", @"next", @"shadersList", @"metrics", @"settings", @"fullScreen", NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, NSToolbarSpaceItemIdentifier];
}

#pragma mark - Shader List Setup

- (void)setupShaderList {
    // Create shaders list view controller
    _shadersListVC = [[ShadersListViewController alloc] init];
    
    // Container view will be created when shown
    _shaderListContainer = nil;
}

- (void)showShadersList {
    [self showShaderList:!_showingShaderList];
}

- (void)showShaderList:(BOOL)show {
    _showingShaderList = show;
    
    NSView *contentView = self.window.contentView;
    
    if (show) {
        if (!_shaderListContainer) {
            NSRect frame = NSMakeRect(0, 0, 200, contentView.bounds.size.height);
            _shaderListContainer = [[NSView alloc] initWithFrame:frame];
            _shaderListContainer.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
            _shaderListContainer.layer.backgroundColor = [NSColor colorWithWhite:0.1 alpha:0.9].CGColor;
            
            NSView *listView = _shadersListVC.view;
            listView.frame = _shaderListContainer.bounds;
            listView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            
            [_shaderListContainer addSubview:listView];
        }
        
        [contentView addSubview:_shaderListContainer];
        
        // Animate in
        NSRect frame = _shaderListContainer.frame;
        frame.origin.x = -frame.size.width;
        _shaderListContainer.frame = frame;
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.3;
            _shaderListContainer.animator.frame = NSMakeRect(0, 0, 200, contentView.bounds.size.height);
        } completionHandler:nil];
        
    } else {
        if (_shaderListContainer) {
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.3;
                _shaderListContainer.animator.frame = NSMakeRect(-200, 0, 200, contentView.bounds.size.height);
            } completionHandler:^{
                [_shaderListContainer removeFromSuperview];
            }];
        }
    }
}

#pragma mark - Metrics Display Setup

- (void)setupMetricsDisplay {
    // Metrics will be shown in a floating panel or overlay
    _metricsContainer = nil;
}

- (void)toggleMetrics {
    [self showMetrics:!_showingMetrics];
}

- (void)showMetrics:(BOOL)show {
    _showingMetrics = show;
    
    // For now, just log metrics
    if (show) {
        NSLog(@"Metrics: FPS=%.1f, GPU=%.2fms, Dropped=%ld", 
              _currentFPS, _gpuTime, (long)_droppedFrames);
    }
}

#pragma mark - Shader Management

- (void)setAvailableShaders:(NSArray<NSString *> *)shaders {
    _availableShaders = shaders ?: @[];
    
    // Update popup button
    if (_shaderSelectorItem && [_shaderSelectorItem.view isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *popup = (NSPopUpButton *)_shaderSelectorItem.view;
        [popup removeAllItems];
        [popup addItemsWithTitles:_availableShaders];
        
        // Select current shader
        if (_currentShader) {
            NSInteger index = [_availableShaders indexOfObject:_currentShader];
            if (index != NSNotFound) {
                [popup selectItemAtIndex:index];
            }
        }
    }
    
    // Update shaders list view controller
    _shadersListVC.shaders = _availableShaders;
}

- (void)selectShader:(NSString *)shaderName {
    if (!shaderName || [_currentShader isEqualToString:shaderName]) return;
    
    _currentShader = shaderName;
    _shaderStartTime = 0; // Reset timing
    
    // Update UI
    _shaderNameLabel.stringValue = shaderName;
    
    // Update popup
    if (_shaderSelectorItem && [_shaderSelectorItem.view isKindOfClass:[NSPopUpButton class]]) {
        NSPopUpButton *popup = (NSPopUpButton *)_shaderSelectorItem.view;
        NSInteger index = [_availableShaders indexOfObject:shaderName];
        if (index != NSNotFound) {
            [popup selectItemAtIndex:index];
        }
    }
    
    // Update shaders list
    [_shadersListVC onShaderSelected:shaderName];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(windowController:didSelectShader:)]) {
        [self.delegate windowController:self didSelectShader:shaderName];
    }
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ShaderDidChange" 
                                                        object:self 
                                                      userInfo:@{@"shader": shaderName}];
}

- (void)selectShaderAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_availableShaders.count) return;
    
    _currentShaderIndex = index;
    [self selectShader:_availableShaders[index]];
}

- (void)nextShader {
    NSInteger nextIndex = _currentShaderIndex + 1;
    if (nextIndex >= (NSInteger)_availableShaders.count) {
        nextIndex = 0;
    }
    [self selectShaderAtIndex:nextIndex];
}

- (void)previousShader {
    NSInteger prevIndex = _currentShaderIndex - 1;
    if (prevIndex < 0) {
        prevIndex = (NSInteger)_availableShaders.count - 1;
    }
    [self selectShaderAtIndex:prevIndex];
}

- (void)shaderPopupSelected:(NSPopUpButton *)popup {
    NSInteger index = popup.indexOfSelectedItem;
    if (index >= 0 && index < (NSInteger)_availableShaders.count) {
        [self selectShaderAtIndex:index];
    }
}

#pragma mark - Full Screen

- (void)toggleFullScreen {
    [self.window toggleFullScreen:nil];
}

#pragma mark - Settings

- (void)showSettings {
    PreferencesWindowController *prefs = [[PreferencesWindowController alloc] init];
    [prefs showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [prefs.window makeKeyAndOrderFront:nil];
}

#pragma mark - UI Updates

- (void)updateShaderList {
    [_shadersListVC refreshPresets];
}

- (void)updateMetrics {
    if (!_renderer) return;
    
    MetalPerformanceMetrics *metrics = [_renderer getMetrics];
    if (!metrics) return;
    
    _currentFPS = metrics.currentFPS;
    _gpuTime = metrics.gpuTimeMs;
    _droppedFrames = metrics.droppedFrames;
    
    // Update FPS label
    if (_fpsLabel) {
        _fpsLabel.stringValue = [NSString stringWithFormat:@"%.1f FPS", _currentFPS];
    }
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(windowController:didUpdateMetrics:)]) {
        NSDictionary *metricsDict = @{
            @"fps": @(_currentFPS),
            @"gpuTime": @(_gpuTime),
            @"droppedFrames": @(_droppedFrames)
        };
        [self.delegate windowController:self didUpdateMetrics:metricsDict];
    }
}

#pragma mark - Callbacks

- (void)onShaderSelected:(NSString *)shaderName {
    [self selectShader:shaderName];
}

- (void)onMetricsUpdated:(NSDictionary *)metrics {
    // Already handled in updateMetrics
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    // Cleanup when window closes
}

- (void)windowDidResize:(NSNotification *)notification {
    // Update viewport size if renderer exists
    if (_renderer && _metalView) {
        CGSize size = _metalView.drawableSize;
        [_renderer setViewportSize:CGSizeMake(size.width, size.height)];
    }
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    // Update viewport
    if (_renderer && _metalView) {
        CGSize size = _metalView.drawableSize;
        [_renderer setViewportSize:CGSizeMake(size.width, size.height)];
    }
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    // Update viewport
    if (_renderer && _metalView) {
        CGSize size = _metalView.drawableSize;
        [_renderer setViewportSize:CGSizeMake(size.width, size.height)];
    }
}

#pragma mark - MetalRendererDelegate

- (void)metalRenderer:(id)renderer didUpdateMetrics:(MetalPerformanceMetrics *)metrics {
    _currentFPS = metrics.currentFPS;
    _gpuTime = metrics.gpuTimeMs;
    _droppedFrames = metrics.droppedFrames;
    
    [self updateMetrics];
}

- (void)metalRenderer:(id)renderer didEncounterError:(MetalRendererError *)error {
    NSLog(@"Renderer error: %@ - %@", error.message, error.compilerError ?: @"");
    
    if ([self.delegate respondsToSelector:@selector(windowController:didEncounterError:)]) {
        [self.delegate windowController:self didEncounterError:error];
    }
}

- (void)metalRenderer:(id)renderer didReloadShadersWithName:(NSString *)shaderName {
    NSLog(@"Shaders reloaded for: %@", shaderName);
}

@end
