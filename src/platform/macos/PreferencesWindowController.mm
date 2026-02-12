//
//  PreferencesWindowController.mm
//  ShaderCandy
//
//  Preferences window controller for the standalone player
//

#import "PreferencesWindowController.h"
#import "../../config/ConfigurationManager.h"

@interface PreferencesWindowController () <NSTabViewDelegate>

// Tab views
@property(nonatomic, strong) NSTabView *tabView;
@property(nonatomic, strong) NSTabViewItem *displayTab;
@property(nonatomic, strong) NSTabViewItem *audioTab;
@property(nonatomic, strong) NSTabViewItem *performanceTab;
@property(nonatomic, strong) NSTabViewItem *shadersTab;

// Display controls
@property(nonatomic, strong) NSPopUpButton *fpsPopup;
@property(nonatomic, strong) NSButton *vsyncCheckbox;
@property(nonatomic, strong) NSButton *hdrCheckbox;
@property(nonatomic, strong) NSPopUpButton *multisamplePopup;

// Audio controls
@property(nonatomic, strong) NSButton *audioEnabledCheckbox;
@property(nonatomic, strong) NSSlider *audioSensitivitySlider;
@property(nonatomic, strong) NSTextField *audioSensitivityLabel;
@property(nonatomic, strong) NSSlider *audioSmoothingSlider;
@property(nonatomic, strong) NSTextField *audioSmoothingLabel;

// Performance controls
@property(nonatomic, strong) NSButton *adaptiveQualityCheckbox;
@property(nonatomic, strong) NSSlider *autoScaleThresholdSlider;
@property(nonatomic, strong) NSTextField *autoScaleThresholdLabel;
@property(nonatomic, strong) NSButton *showFPSCheckbox;

// Shader controls
@property(nonatomic, strong) NSButton *hotReloadCheckbox;
@property(nonatomic, strong) NSPopUpButton *defaultShaderPopup;

// Buttons
@property(nonatomic, strong) NSButton *saveButton;
@property(nonatomic, strong) NSButton *cancelButton;
@property(nonatomic, strong) NSButton *resetButton;

@end

@implementation PreferencesWindowController

- (instancetype)init {
    self = [super initWithWindowNibName:@"PreferencesWindow"];
    if (self) {
        [self loadDefaults];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self setupUI];
    [self loadCurrentPreferences];
}

#pragma mark - Default Values

- (void)loadDefaults {
    _targetFPS = 60;
    _vsyncEnabled = YES;
    _hdrEnabled = NO;
    _multisampleLevel = 1;
    
    _audioEnabled = NO;
    _audioSensitivity = 1.0f;
    _audioSmoothing = 0.3f;
    
    _adaptiveQuality = YES;
    _showFPS = NO;
    _autoScaleThreshold = 45.0f;
    
    _hotReloadEnabled = YES;
    _defaultShader = @"plasma";
}

#pragma mark - UI Setup

- (void)setupUI {
    if (!self.window) return;
    
    self.window.title = @"Preferences";
    self.window.styleMask &= ~NSWindowStyleMaskResizable;
    
    // Create tab view
    _tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(0, 60, 400, 250)];
    _tabView.delegate = self;
    [self.window.contentView addSubview:_tabView];
    
    // Display tab
    _displayTab = [[NSTabViewItem alloc] initWithIdentifier:@"display"];
    _displayTab.label = @"Display";
    [_tabView addTabViewItem:_displayTab];
    [self setupDisplayTab];
    
    // Audio tab
    _audioTab = [[NSTabViewItem alloc] initWithIdentifier:@"audio"];
    _audioTab.label = @"Audio";
    [_tabView addTabViewItem:_audioTab];
    [self setupAudioTab];
    
    // Performance tab
    _performanceTab = [[NSTabViewItem alloc] initWithIdentifier:@"performance"];
    _performanceTab.label = @"Performance";
    [_tabView addTabViewItem:_performanceTab];
    [self setupPerformanceTab];
    
    // Shaders tab
    _shadersTab = [[NSTabViewItem alloc] initWithIdentifier:@"shaders"];
    _shadersTab.label = @"Shaders";
    [_tabView addTabViewItem:_shadersTab];
    [self setupShadersTab];
    
    // Buttons
    [self setupButtons];
}

- (void)setupDisplayTab {
    NSView *content = _displayTab.view;
    
    // Target FPS
    NSTextField *fpsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 200, 120, 20)];
    fpsLabel.stringValue = @"Target FPS:";
    fpsLabel.editable = NO;
    fpsLabel.bordered = NO;
    fpsLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:fpsLabel];
    
    _fpsPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 200, 100, 24)];
    [_fpsPopup addItemsWithTitles:@[@"30", @"45", @"60", @"75", @"90", @"120"]];
    [content addSubview:_fpsPopup];
    
    // VSync
    _vsyncCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 165, 200, 24)];
    _vsyncCheckbox.buttonType = NSButtonTypeSwitch;
    _vsyncCheckbox.title = @"Enable VSync";
    _vsyncCheckbox.state = NSControlStateValueOn;
    [content addSubview:_vsyncCheckbox];
    
    // HDR
    _hdrCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 130, 200, 24)];
    _hdrCheckbox.buttonType = NSButtonTypeSwitch;
    _hdrCheckbox.title = @"Enable HDR (if available)";
    [content addSubview:_hdrCheckbox];
    
    // Multisample
    NSTextField *msaaLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 90, 120, 20)];
    msaaLabel.stringValue = @"Anti-Aliasing:";
    msaaLabel.editable = NO;
    msaaLabel.bordered = NO;
    msaaLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:msaaLabel];
    
    _multisamplePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 90, 100, 24)];
    [_multisamplePopup addItemsWithTitles:@[@"Off", @"2x", @"4x"]];
    [_multisamplePopup selectItemAtIndex:0];
    [content addSubview:_multisamplePopup];
}

- (void)setupAudioTab {
    NSView *content = _audioTab.view;
    
    // Audio enabled
    _audioEnabledCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
    _audioEnabledCheckbox.buttonType = NSButtonTypeSwitch;
    _audioEnabledCheckbox.title = @"Enable Audio Reactivity";
    [content addSubview:_audioEnabledCheckbox];
    
    // Audio sensitivity
    NSTextField *sensitivityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 155, 150, 20)];
    sensitivityLabel.stringValue = @"Audio Sensitivity:";
    sensitivityLabel.editable = NO;
    sensitivityLabel.bordered = NO;
    sensitivityLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:sensitivityLabel];
    
    _audioSensitivitySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(180, 155, 180, 24)];
    _audioSensitivitySlider.minValue = 0.1;
    _audioSensitivitySlider.maxValue = 3.0;
    _audioSensitivitySlider.floatValue = 1.0;
    [content addSubview:_audioSensitivitySlider];
    
    _audioSensitivityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(370, 155, 30, 24)];
    _audioSensitivityLabel.stringValue = @"1.0";
    _audioSensitivityLabel.editable = NO;
    _audioSensitivityLabel.bordered = NO;
    _audioSensitivityLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:_audioSensitivityLabel];
    
    // Audio smoothing
    NSTextField *smoothingLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 110, 150, 20)];
    smoothingLabel.stringValue = @"Audio Smoothing:";
    smoothingLabel.editable = NO;
    smoothingLabel.bordered = NO;
    smoothingLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:smoothingLabel];
    
    _audioSmoothingSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(180, 110, 180, 24)];
    _audioSmoothingSlider.minValue = 0.0;
    _audioSmoothingSlider.maxValue = 0.9;
    _audioSmoothingSlider.floatValue = 0.3;
    [content addSubview:_audioSmoothingSlider];
    
    _audioSmoothingLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(370, 110, 30, 24)];
    _audioSmoothingLabel.stringValue = @"0.3";
    _audioSmoothingLabel.editable = NO;
    _audioSmoothingLabel.bordered = NO;
    _audioSmoothingLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:_audioSmoothingLabel];
    
    // Bind slider values
    [_audioSensitivitySlider bind:NSValueBinding 
                         toObject:self 
                      withKeyPath:@"audioSensitivity" 
                          options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
    [_audioSmoothingSlider bind:NSValueBinding 
                       toObject:self 
                    withKeyPath:@"audioSmoothing" 
                        options:@{NSContinuouslyUpdatesValueBindingOption: @YES}];
}

- (void)setupPerformanceTab {
    NSView *content = _performanceTab.view;
    
    // Adaptive quality
    _adaptiveQualityCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
    _adaptiveQualityCheckbox.buttonType = NSButtonTypeSwitch;
    _adaptiveQualityCheckbox.title = @"Adaptive Quality";
    _adaptiveQualityCheckbox.state = NSControlStateValueOn;
    [content addSubview:_adaptiveQualityCheckbox];
    
    // Show FPS
    _showFPSCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 165, 200, 24)];
    _showFPSCheckbox.buttonType = NSButtonTypeSwitch;
    _showFPSCheckbox.title = @"Show FPS Counter";
    [content addSubview:_showFPSCheckbox];
    
    // Auto scale threshold
    NSTextField *thresholdLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 115, 180, 20)];
    thresholdLabel.stringValue = @"FPS Threshold for Scaling:";
    thresholdLabel.editable = NO;
    thresholdLabel.bordered = NO;
    thresholdLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:thresholdLabel];
    
    _autoScaleThresholdSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(200, 115, 160, 24)];
    _autoScaleThresholdSlider.minValue = 30;
    _autoScaleThresholdSlider.maxValue = 60;
    _autoScaleThresholdSlider.floatValue = 45;
    [content addSubview:_autoScaleThresholdSlider];
    
    _autoScaleThresholdLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(370, 115, 30, 24)];
    _autoScaleThresholdLabel.stringValue = @"45";
    _autoScaleThresholdLabel.editable = NO;
    _autoScaleThresholdLabel.bordered = NO;
    _autoScaleThresholdLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:_autoScaleThresholdLabel];
}

- (void)setupShadersTab {
    NSView *content = _shadersTab.view;
    
    // Hot reload
    _hotReloadCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
    _hotReloadCheckbox.buttonType = NSButtonTypeSwitch;
    _hotReloadCheckbox.title = @"Enable Hot Reload";
    _hotReloadCheckbox.state = NSControlStateValueOn;
    [content addSubview:_hotReloadCheckbox];
    
    // Default shader
    NSTextField *defaultLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 155, 120, 20)];
    defaultLabel.stringValue = @"Default Shader:";
    defaultLabel.editable = NO;
    defaultLabel.bordered = NO;
    defaultLabel.backgroundColor = [NSColor clearColor];
    [content addSubview:defaultLabel];
    
    _defaultShaderPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 155, 150, 24)];
    [_defaultShaderPopup addItemsWithTitles:@[@"plasma", @"mandelbulb_3d", @"nebula", @"vortex"]];
    [content addSubview:_defaultShaderPopup];
}

- (void)setupButtons {
    // Cancel button
    _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(200, 10, 80, 30)];
    _cancelButton.buttonType = NSButtonTypeMomentaryPushIn;
    _cancelButton.title = @"Cancel";
    _cancelButton.action = @selector(cancelPressed:);
    _cancelButton.keyEquivalent = @"\E";  // Escape
    [self.window.contentView addSubview:_cancelButton];
    
    // Reset button
    _resetButton = [[NSButton alloc] initWithFrame:NSMakeRect(120, 10, 80, 30)];
    _resetButton.buttonType = NSButtonTypeMomentaryPushIn;
    _resetButton.title = @"Reset";
    _resetButton.action = @selector(resetPressed:);
    [self.window.contentView addSubview:_resetButton];
    
    // Save button
    _saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(300, 10, 80, 30)];
    _saveButton.buttonType = NSButtonTypeMomentaryPushIn;
    _saveButton.title = @"Save";
    _saveButton.action = @selector(savePressed:);
    _saveButton.keyEquivalent = @"\r";  // Return
    _saveButton.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.window.contentView addSubview:_saveButton];
}

#pragma mark - Load/Save

- (void)loadCurrentPreferences {
    auto &config = ShaderCandy::Config::ConfigurationManager::getInstance();
    const auto &settings = config.getSettings();
    
    _targetFPS = settings.targetFPS;
    _vsyncEnabled = settings.vsync;
    _hdrEnabled = settings.hdr;
    _multisampleLevel = settings.multisampleLevel;
    
    _audioEnabled = settings.enableAudio;
    _audioSensitivity = settings.audioSensitivity;
    _audioSmoothing = settings.audioSmoothing;
    
    _adaptiveQuality = settings.adaptiveQuality;
    _showFPS = settings.showFPS;
    _autoScaleThreshold = settings.autoScaleFPSThreshold;
    
    _hotReloadEnabled = settings.enableHotReload;
    _defaultShader = [NSString stringWithUTF8String:settings.defaultShader.c_str()];
    
    // Update UI
    [_fpsPopup selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)_targetFPS]];
    _vsyncCheckbox.state = _vsyncEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _hdrCheckbox.state = _hdrEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [_multisamplePopup selectItemWithTag:_multisampleLevel];
    
    _audioEnabledCheckbox.state = _audioEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _audioSensitivitySlider.floatValue = _audioSensitivity;
    _audioSensitivityLabel.stringValue = [NSString stringWithFormat:@"%.1f", _audioSensitivity];
    _audioSmoothingSlider.floatValue = _audioSmoothing;
    _audioSmoothingLabel.stringValue = [NSString stringWithFormat:@"%.1f", _audioSmoothing];
    
    _adaptiveQualityCheckbox.state = _adaptiveQuality ? NSControlStateValueOn : NSControlStateValueOff;
    _showFPSCheckbox.state = _showFPS ? NSControlStateValueOn : NSControlStateValueOff;
    _autoScaleThresholdSlider.floatValue = _autoScaleThreshold;
    _autoScaleThresholdLabel.stringValue = [NSString stringWithFormat:@"%.0f", _autoScaleThreshold];
    
    _hotReloadCheckbox.state = _hotReloadEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Update shader popup
    [_defaultShaderPopup removeAllItems];
    // Add all available shaders would go here
    [_defaultShaderPopup addItemWithTitle:[NSString stringWithUTF8String:settings.defaultShader.c_str()]];
}

- (void)savePreferences {
    auto &config = ShaderCandy::Config::ConfigurationManager::getInstance();
    auto &settings = config.getSettings();
    
    settings.targetFPS = _targetFPS;
    settings.vsync = _vsyncEnabled;
    settings.hdr = _hdrEnabled;
    settings.multisampleLevel = _multisampleLevel;
    
    settings.enableAudio = _audioEnabled;
    settings.audioSensitivity = _audioSensitivity;
    settings.audioSmoothing = _audioSmoothing;
    
    settings.adaptiveQuality = _adaptiveQuality;
    settings.showFPS = _showFPS;
    settings.autoScaleFPSThreshold = _autoScaleThreshold;
    
    settings.enableHotReload = _hotReloadEnabled;
    settings.defaultShader = [_defaultShader UTF8String];
    
    // Save to disk
    config.saveToFile(ShaderCandy::Config::ConfigurationManager::getConfigDirectory() + "/standalone.json");
}

#pragma mark - Actions

- (void)savePressed:(id)sender {
    [self savePreferences];
    [self.window close];
}

- (void)cancelPressed:(id)sender {
    [self.window close];
}

- (void)resetPressed:(id)sender {
    [self loadDefaults];
    [self loadCurrentPreferences];
}

- (void)setAudioSensitivity:(float)audioSensitivity {
    _audioSensitivity = audioSensitivity;
    _audioSensitivityLabel.stringValue = [NSString stringWithFormat:@"%.1f", audioSensitivity];
}

- (void)setAudioSmoothing:(float)audioSmoothing {
    _audioSmoothing = audioSmoothing;
    _audioSmoothingLabel.stringValue = [NSString stringWithFormat:@"%.1f", audioSmoothing];
}

- (void)setAutoScaleThreshold:(float)autoScaleThreshold {
    _autoScaleThreshold = autoScaleThreshold;
    _autoScaleThresholdLabel.stringValue = [NSString stringWithFormat:@"%.0f", autoScaleThreshold];
}

@end
