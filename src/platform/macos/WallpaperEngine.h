//
//  WallpaperEngine.h
//  ShaderCandy
//
//  Engine for managing ShaderCandy as a desktop wallpaper
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DesktopView;
@class MetalRenderer;

// Notification names
extern NSString *const WallpaperEngineDidStartNotification;
extern NSString *const WallpaperEngineDidStopNotification;
extern NSString *const WallpaperEngineDidChangeShaderNotification;
extern NSString *const WallpaperEngineDidEncounterErrorNotification;

@interface WallpaperEngine : NSObject

// Singleton
+ (instancetype)sharedEngine;

// State
@property(nonatomic, assign, readonly) BOOL isActive;
@property(nonatomic, assign, readonly) BOOL isRunning;
@property(nonatomic, strong, readonly, nullable) NSString *currentShader;
@property(nonatomic, strong, readonly, nullable) NSString *currentDesktopID;

// Configuration
@property(nonatomic, assign) BOOL startAtLogin;
@property(nonatomic, assign) BOOL pauseOnBattery;
@property(nonatomic, assign) BOOL pauseOnScreenLock;
@property(nonatomic, assign) BOOL enableAudio;

// Display Management
@property(nonatomic, assign, readonly) NSInteger displayCount;
@property(nonatomic, strong, readonly) NSArray<NSString *> *displayIDs;

// Desktop Management
- (BOOL)setWallpaperForDesktop:(NSString *)desktopID
                    withShader:(NSString *)shaderName;
- (BOOL)setWallpaperForAllDesktops:(NSString *)shaderName;
- (BOOL)setWallpaperForCurrentSpace:(NSString *)shaderName;
- (void)clearWallpaper;
- (void)clearWallpaperForDesktop:(NSString *)desktopID;

// Control
- (BOOL)start;
- (void)stop;
- (void)pause;
- (void)resume;

// Shader Management
- (void)switchToShader:(NSString *)shaderName;
- (void)nextShader;
- (void)previousShader;

// Display Configuration
- (NSString *)primaryDisplayID;
- (NSString *)displayIDForWindow:(NSWindow *)window;
- (CGDirectDisplayID)cgDisplayIDForDesktopID:(NSString *)desktopID;

// Lifecycle
- (void)handleScreenWake;
- (void)handleScreenSleep;
- (void)handleSpaceChange;

@end

NS_ASSUME_NONNULL_END
