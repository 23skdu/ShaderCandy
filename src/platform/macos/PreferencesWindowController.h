//
//  PreferencesWindowController.h
//  ShaderCandy
//
//  Preferences window controller for the standalone player
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreferencesWindowController : NSWindowController

// Display Settings
@property(nonatomic, assign) NSInteger targetFPS;
@property(nonatomic, assign) BOOL vsyncEnabled;
@property(nonatomic, assign) BOOL hdrEnabled;
@property(nonatomic, assign) NSInteger multisampleLevel;

// Audio Settings
@property(nonatomic, assign) BOOL audioEnabled;
@property(nonatomic, assign) float audioSensitivity;
@property(nonatomic, assign) float audioSmoothing;

// Performance Settings
@property(nonatomic, assign) BOOL adaptiveQuality;
@property(nonatomic, assign) BOOL showFPS;
@property(nonatomic, assign) float autoScaleThreshold;

// Shader Settings
@property(nonatomic, assign) BOOL hotReloadEnabled;
@property(nonatomic, strong) NSString *defaultShader;
@property(nonatomic, strong) NSArray<NSString *> *availableShaders;

// Initialization
- (instancetype)init;

// Actions
- (void)savePreferences;
- (void)resetToDefaults;

@end

NS_ASSUME_NONNULL_END
