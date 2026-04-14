//
//  PreferencesWindowController.mm
//  ShaderCandy
//
//  Preferences window controller for the standalone player
//

#import "PreferencesWindowController.h"
#import "../../config/ConfigurationManager.h"
#import "../../neural/NeuralStyleEngine.h"

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

// Calibration controls
@property(nonatomic, strong) NSTextField *peakBrightnessField;
@property(nonatomic, strong) NSTextField *whitePointField;

// Buttons
@property(nonatomic, strong) NSButton *saveButton;
@property(nonatomic, strong) NSButton *cancelButton;
@property(nonatomic, strong) NSButton *resetButton;

@end

@implementation PreferencesWindowController

- (instancetype)init {
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 550, 550)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self = [super initWithWindow:window];
  if (self) {
    [self resetToDefaults];
    [self setupUI];
    [self loadCurrentPreferences];
  }
  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];

  [self setupUI];
  [self loadCurrentPreferences];
}

#pragma mark - Default Values

- (void)resetToDefaults {
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
  _defaultShader = @"default";
}

#pragma mark - UI Setup

- (void)setupUI {
  if (!self.window)
    return;

  self.window.title = @"Preferences";
  self.window.styleMask &= ~NSWindowStyleMaskResizable;

  // Create tab view
  _tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(0, 60, 530, 420)];
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

  // Neural tab
  NSTabViewItem *neuralTab =
      [[NSTabViewItem alloc] initWithIdentifier:@"neural"];
  neuralTab.label = @"Neural";
  [_tabView addTabViewItem:neuralTab];
  [self setupNeuralTab:neuralTab.view];

  // Advanced tab
  NSTabViewItem *advancedTab =
      [[NSTabViewItem alloc] initWithIdentifier:@"advanced"];
  advancedTab.label = @"Advanced";
  [_tabView addTabViewItem:advancedTab];
  [self setupAdvancedTab:advancedTab.view];

  // Buttons
  [self setupButtons];
}

- (void)setupDisplayTab {
  NSView *content = _displayTab.view;

  // Target FPS
  NSTextField *fpsLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 200, 120, 20)];
  fpsLabel.stringValue = @"Target FPS:";
  fpsLabel.editable = NO;
  fpsLabel.bordered = NO;
  fpsLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:fpsLabel];

  _fpsPopup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 200, 100, 24)];
  [_fpsPopup addItemsWithTitles:@[ @"30", @"45", @"60", @"75", @"90", @"120" ]];
  [content addSubview:_fpsPopup];

  // VSync
  _vsyncCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 165, 200, 24)];
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
  NSTextField *msaaLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 90, 120, 20)];
  msaaLabel.stringValue = @"Anti-Aliasing:";
  msaaLabel.editable = NO;
  msaaLabel.bordered = NO;
  msaaLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:msaaLabel];

  _multisamplePopup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 90, 100, 24)];
  [_multisamplePopup addItemsWithTitles:@[ @"Off", @"2x", @"4x" ]];
  [_multisamplePopup selectItemAtIndex:0];
  [content addSubview:_multisamplePopup];

  // HDR Calibration
  NSTextField *calibrationLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 55, 120, 20)];
  calibrationLabel.stringValue = @"HDR Calibration:";
  calibrationLabel.editable = NO;
  calibrationLabel.bordered = NO;
  calibrationLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:calibrationLabel];

  NSButton *calibrationButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(150, 53, 180, 24)];
  calibrationButton.title = @"Show Color Bars";
  calibrationButton.bezelStyle = NSBezelStyleRounded;
  calibrationButton.target = self;
  calibrationButton.action = @selector(showCalibrationPattern:);
  [content addSubview:calibrationButton];
}

- (void)showCalibrationPattern:(id)sender {
  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"ShaderDidChange"
                    object:self
                  userInfo:@{@"shader" : @"calibration"}];
}

- (void)setupAudioTab {
  NSView *content = _audioTab.view;

  // Audio enabled
  _audioEnabledCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
  _audioEnabledCheckbox.buttonType = NSButtonTypeSwitch;
  _audioEnabledCheckbox.title = @"Enable Audio Reactivity";
  [content addSubview:_audioEnabledCheckbox];

  // Audio sensitivity
  NSTextField *sensitivityLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 155, 150, 20)];
  sensitivityLabel.stringValue = @"Audio Sensitivity:";
  sensitivityLabel.editable = NO;
  sensitivityLabel.bordered = NO;
  sensitivityLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:sensitivityLabel];

  _audioSensitivitySlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(180, 155, 180, 24)];
  _audioSensitivitySlider.minValue = 0.1;
  _audioSensitivitySlider.maxValue = 3.0;
  _audioSensitivitySlider.floatValue = 1.0;
  [content addSubview:_audioSensitivitySlider];

  _audioSensitivityLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(370, 155, 30, 24)];
  _audioSensitivityLabel.stringValue = @"1.0";
  _audioSensitivityLabel.editable = NO;
  _audioSensitivityLabel.bordered = NO;
  _audioSensitivityLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:_audioSensitivityLabel];

  // Audio smoothing
  NSTextField *smoothingLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 110, 150, 20)];
  smoothingLabel.stringValue = @"Audio Smoothing:";
  smoothingLabel.editable = NO;
  smoothingLabel.bordered = NO;
  smoothingLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:smoothingLabel];

  _audioSmoothingSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(180, 110, 180, 24)];
  _audioSmoothingSlider.minValue = 0.0;
  _audioSmoothingSlider.maxValue = 0.9;
  _audioSmoothingSlider.floatValue = 0.3;
  [content addSubview:_audioSmoothingSlider];

  _audioSmoothingLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(370, 110, 30, 24)];
  _audioSmoothingLabel.stringValue = @"0.3";
  _audioSmoothingLabel.editable = NO;
  _audioSmoothingLabel.bordered = NO;
  _audioSmoothingLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:_audioSmoothingLabel];

  // Bind slider values
  [_audioSensitivitySlider
             bind:NSValueBinding
         toObject:self
      withKeyPath:@"audioSensitivity"
          options:@{NSContinuouslyUpdatesValueBindingOption : @YES}];
  [_audioSmoothingSlider
             bind:NSValueBinding
         toObject:self
      withKeyPath:@"audioSmoothing"
          options:@{NSContinuouslyUpdatesValueBindingOption : @YES}];
}

- (void)setupPerformanceTab {
  NSView *content = _performanceTab.view;

  // Adaptive quality
  _adaptiveQualityCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
  _adaptiveQualityCheckbox.buttonType = NSButtonTypeSwitch;
  _adaptiveQualityCheckbox.title = @"Adaptive Quality";
  _adaptiveQualityCheckbox.state = NSControlStateValueOn;
  [content addSubview:_adaptiveQualityCheckbox];

  // Show FPS
  _showFPSCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 165, 200, 24)];
  _showFPSCheckbox.buttonType = NSButtonTypeSwitch;
  _showFPSCheckbox.title = @"Show FPS Counter";
  [content addSubview:_showFPSCheckbox];

  // Auto scale threshold
  NSTextField *thresholdLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 115, 180, 20)];
  thresholdLabel.stringValue = @"FPS Threshold for Scaling:";
  thresholdLabel.editable = NO;
  thresholdLabel.bordered = NO;
  thresholdLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:thresholdLabel];

  _autoScaleThresholdSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(200, 115, 160, 24)];
  _autoScaleThresholdSlider.minValue = 30;
  _autoScaleThresholdSlider.maxValue = 60;
  _autoScaleThresholdSlider.floatValue = 45;
  [content addSubview:_autoScaleThresholdSlider];

  _autoScaleThresholdLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(370, 115, 30, 24)];
  _autoScaleThresholdLabel.stringValue = @"45";
  _autoScaleThresholdLabel.editable = NO;
  _autoScaleThresholdLabel.bordered = NO;
  _autoScaleThresholdLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:_autoScaleThresholdLabel];
}

- (void)setupShadersTab {
  NSView *content = _shadersTab.view;

  // Hot reload
  _hotReloadCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
  _hotReloadCheckbox.buttonType = NSButtonTypeSwitch;
  _hotReloadCheckbox.title = @"Enable Hot Reload";
  _hotReloadCheckbox.state = NSControlStateValueOn;
  [content addSubview:_hotReloadCheckbox];

  // Default shader
  NSTextField *defaultLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 155, 120, 20)];
  defaultLabel.stringValue = @"Default Shader:";
  defaultLabel.editable = NO;
  defaultLabel.bordered = NO;
  defaultLabel.backgroundColor = [NSColor clearColor];
  [content addSubview:defaultLabel];

  _defaultShaderPopup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 155, 150, 24)];
  if (_availableShaders.count > 0) {
    [_defaultShaderPopup addItemsWithTitles:_availableShaders];
  } else {
    [_defaultShaderPopup addItemWithTitle:@"default"];
  }
  [content addSubview:_defaultShaderPopup];
}

- (void)setupButtons {
  // Cancel button
  _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(200, 10, 80, 30)];
  _cancelButton.buttonType = NSButtonTypeMomentaryPushIn;
  _cancelButton.title = @"Cancel";
  _cancelButton.action = @selector(cancelPressed:);
  _cancelButton.keyEquivalent = @"\E"; // Escape
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
  _saveButton.keyEquivalent = @"\r"; // Return
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
  _defaultShader =
      [NSString stringWithUTF8String:settings.defaultShader.c_str()];

  _neuralEnabled = settings.neuralStyleEnabled;
  _styleStrength = settings.neuralStyleStrength;
  _neuralStyle =
      [NSString stringWithUTF8String:settings.neuralStyleName.c_str()];

  _spatialAudioEnabled = settings.spatialAudio;
  _roomSize = settings.roomSize;
  _reverbDamping = settings.reverbDamping;

  _calibrationModeEnabled = NO;
  _calibrationPeakBrightness = 1000.0f;
  _calibrationWhitePoint = 6500.0f;
  _calibrationType = 0;

  // Update UI
  [_fpsPopup
      selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)_targetFPS]];
  _vsyncCheckbox.state =
      _vsyncEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  _hdrCheckbox.state =
      _hdrEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  [_multisamplePopup selectItemWithTag:_multisampleLevel];

  _audioEnabledCheckbox.state =
      _audioEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  _audioSensitivitySlider.floatValue = _audioSensitivity;
  _audioSensitivityLabel.stringValue =
      [NSString stringWithFormat:@"%.1f", _audioSensitivity];
  _audioSmoothingSlider.floatValue = _audioSmoothing;
  _audioSmoothingLabel.stringValue =
      [NSString stringWithFormat:@"%.1f", _audioSmoothing];

  _adaptiveQualityCheckbox.state =
      _adaptiveQuality ? NSControlStateValueOn : NSControlStateValueOff;
  _showFPSCheckbox.state =
      _showFPS ? NSControlStateValueOn : NSControlStateValueOff;
  _autoScaleThresholdSlider.floatValue = _autoScaleThreshold;
  _autoScaleThresholdLabel.stringValue =
      [NSString stringWithFormat:@"%.0f", _autoScaleThreshold];

  _hotReloadCheckbox.state =
      _hotReloadEnabled ? NSControlStateValueOn : NSControlStateValueOff;

  // Update shader popup
  [_defaultShaderPopup removeAllItems];
  if (_availableShaders.count > 0) {
    [_defaultShaderPopup addItemsWithTitles:_availableShaders];
    if (_defaultShader) {
      [_defaultShaderPopup selectItemWithTitle:_defaultShader];
    }
  } else {
    [_defaultShaderPopup addItemWithTitle:_defaultShader ?: @"default"];
  }
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

  settings.neuralStyleEnabled = _neuralEnabled;
  settings.neuralStyleStrength = _styleStrength;
  if (_neuralStyle)
    settings.neuralStyleName = [_neuralStyle UTF8String];

  settings.spatialAudio = _spatialAudioEnabled;
  settings.roomSize = _roomSize;
  settings.reverbDamping = _reverbDamping;

  // Save to disk
  config.saveToFile(
      ShaderCandy::Config::ConfigurationManager::getConfigDirectory() +
      "/standalone.json");
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
  [self resetToDefaults];
  [self loadCurrentPreferences];
}

- (void)setAudioSensitivity:(float)audioSensitivity {
  _audioSensitivity = audioSensitivity;
  _audioSensitivityLabel.stringValue =
      [NSString stringWithFormat:@"%.1f", audioSensitivity];
}

- (void)setAudioSmoothing:(float)audioSmoothing {
  _audioSmoothing = audioSmoothing;
  _audioSmoothingLabel.stringValue =
      [NSString stringWithFormat:@"%.1f", audioSmoothing];
}

- (void)setAutoScaleThreshold:(float)autoScaleThreshold {
  _autoScaleThreshold = autoScaleThreshold;
  _autoScaleThresholdLabel.stringValue =
      [NSString stringWithFormat:@"%.0f", autoScaleThreshold];
}

- (void)setupNeuralTab:(NSView *)content {
  // Neural Enable
  NSButton *neuralCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
  neuralCheck.buttonType = NSButtonTypeSwitch;
  neuralCheck.title = @"Enable AI Style Transfer";
  neuralCheck.state =
      self.neuralEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  neuralCheck.target = self;
  neuralCheck.action = @selector(neuralToggled:);
  [content addSubview:neuralCheck];

  // Style Strength
  NSTextField *strengthLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 160, 120, 20)];
  strengthLabel.stringValue = @"AI Effect Intensity:";
  strengthLabel.editable = NO;
  strengthLabel.bordered = NO;
  [content addSubview:strengthLabel];

  NSSlider *strengthSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(150, 160, 200, 24)];
  strengthSlider.minValue = 0.0;
  strengthSlider.maxValue = 1.0;
  strengthSlider.floatValue = self.styleStrength;
  strengthSlider.target = self;
  strengthSlider.action = @selector(styleStrengthChanged:);
  [content addSubview:strengthSlider];

  // Import Model Button
  NSButton *importButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 120, 150, 30)];
  importButton.buttonType = NSButtonTypeMomentaryPushIn;
  importButton.title = @"Import Custom Model...";
  importButton.target = self;
  importButton.action = @selector(importModelPressed:);
  [content addSubview:importButton];
}

- (void)setupAdvancedTab:(NSView *)content {
  // Spatial Audio
  NSButton *spatialCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 200, 250, 24)];
  spatialCheck.buttonType = NSButtonTypeSwitch;
  spatialCheck.title = @"Ray-Traced Spatial Audio";
  spatialCheck.state =
      self.spatialAudioEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  spatialCheck.target = self;
  spatialCheck.action = @selector(spatialToggled:);
  [content addSubview:spatialCheck];

  // Room Size
  NSTextField *roomLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 160, 120, 20)];
  roomLabel.stringValue = @"Virtual Room Size:";
  roomLabel.editable = NO;
  roomLabel.bordered = NO;
  [content addSubview:roomLabel];

  NSSlider *roomSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(150, 160, 200, 24)];
  roomSlider.minValue = 0.5;
  roomSlider.maxValue = 5.0;
  roomSlider.floatValue = self.roomSize;
  roomSlider.target = self;
  roomSlider.action = @selector(roomSizeChanged:);
  [content addSubview:roomSlider];

  // HDR Calibration Section
  NSTextField *calibHeader =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 120, 200, 20)];
  calibHeader.stringValue = @"HDR Calibration";
  calibHeader.editable = NO;
  calibHeader.bordered = NO;
  calibHeader.font = [NSFont boldSystemFontOfSize:13];
  [content addSubview:calibHeader];

  NSButton *calibCheck =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 95, 250, 24)];
  calibCheck.buttonType = NSButtonTypeSwitch;
  calibCheck.title = @"Show SMPTE Color Bars";
  calibCheck.state = self.calibrationModeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
  calibCheck.target = self;
  calibCheck.action = @selector(toggleCalibrationMode:);
  [content addSubview:calibCheck];

  // Peak Brightness
  NSTextField *brightLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 65, 100, 20)];
  brightLabel.stringValue = @"Peak (nits):";
  brightLabel.editable = NO;
  brightLabel.bordered = NO;
  [content addSubview:brightLabel];

  NSSlider *brightSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(120, 65, 150, 24)];
  brightSlider.minValue = 100;
  brightSlider.maxValue = 4000;
  brightSlider.floatValue = self.calibrationPeakBrightness;
  brightSlider.target = self;
  brightSlider.action = @selector(calibrationBrightnessChanged:);
  [content addSubview:brightSlider];

  _peakBrightnessField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(280, 65, 60, 20)];
  _peakBrightnessField.intValue = (NSInteger)self.calibrationPeakBrightness;
  _peakBrightnessField.editable = NO;
  _peakBrightnessField.bordered = YES;
  [content addSubview:_peakBrightnessField];

  // White Point
  NSTextField *whiteLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 30, 100, 20)];
  whiteLabel.stringValue = @"White Point:";
  whiteLabel.editable = NO;
  whiteLabel.bordered = NO;
  [content addSubview:whiteLabel];

  NSSlider *whiteSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(120, 30, 150, 24)];
  whiteSlider.minValue = 4000;
  whiteSlider.maxValue = 10000;
  whiteSlider.floatValue = self.calibrationWhitePoint;
  whiteSlider.target = self;
  whiteSlider.action = @selector(calibrationWhitePointChanged:);
  [content addSubview:whiteSlider];

  _whitePointField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(280, 30, 60, 20)];
  _whitePointField.intValue = (NSInteger)self.calibrationWhitePoint;
  _whitePointField.editable = NO;
  _whitePointField.bordered = YES;
  [content addSubview:_whitePointField];
}

- (void)neuralToggled:(NSButton *)sender {
  self.neuralEnabled = sender.state == NSControlStateValueOn;
}

- (void)styleStrengthChanged:(NSSlider *)sender {
  self.styleStrength = sender.floatValue;
}

- (void)spatialToggled:(NSButton *)sender {
  self.spatialAudioEnabled = sender.state == NSControlStateValueOn;
}

- (void)roomSizeChanged:(NSSlider *)sender {
  self.roomSize = sender.floatValue;
}

- (void)importModelPressed:(NSButton *)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.allowedFileTypes = @[ @"mlmodel", @"mlpackage" ];
  panel.canChooseFiles = YES;

  if ([panel runModal] == NSModalResponseOK) {
    NSURL *url = panel.URL;
    NSError *error = nil;

    // Load in engine
    if ([[NeuralStyleEngine sharedEngine] loadModelAtPath:url error:&error]) {
      self.neuralStyle = url.lastPathComponent.stringByDeletingPathExtension;
      NSLog(@"Neural style model loaded: %@", self.neuralStyle);
    } else {
      NSAlert *alert = [NSAlert alertWithError:error];
      [alert runModal];
    }
  }
}

- (void)setAvailableShaders:(NSArray<NSString *> *)availableShaders {
  _availableShaders = availableShaders;
  if (_defaultShaderPopup) {
    [_defaultShaderPopup removeAllItems];
    [_defaultShaderPopup addItemsWithTitles:_availableShaders];
    if (_defaultShader) {
      [_defaultShaderPopup selectItemWithTitle:_defaultShader];
    }
  }
}

- (void)toggleCalibrationMode:(NSButton *)sender {
  self.calibrationModeEnabled = sender.state == NSControlStateValueOn;
  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"ShaderCandyCalibrationModeChanged"
      object:self
      userInfo:@{@"enabled": @(self.calibrationModeEnabled)}];
}

- (void)calibrationBrightnessChanged:(NSSlider *)sender {
  self.calibrationPeakBrightness = sender.floatValue;
  _peakBrightnessField.intValue = (NSInteger)self.calibrationPeakBrightness;
}

- (void)calibrationWhitePointChanged:(NSSlider *)sender {
  self.calibrationWhitePoint = sender.floatValue;
  _whitePointField.intValue = (NSInteger)self.calibrationWhitePoint;
}

@end
