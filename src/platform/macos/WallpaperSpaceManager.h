//
//  WallpaperSpaceManager.h
//  ShaderCandy
//
//  Manages wallpaper assignments per Space on macOS
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface WallpaperSpaceManager : NSObject

// Singleton
+ (instancetype)sharedManager;

// Space Management
@property(nonatomic, strong, readonly) NSArray<NSString *> *allSpaceIDs;
@property(nonatomic, strong, readonly) NSString *currentSpaceID;
@property(nonatomic, strong, readonly) NSString *currentSpaceUUID;

// Assignment Management
- (nullable NSString *)shaderForSpace:(NSString *)spaceID;
- (void)setShader:(NSString *)shaderName forSpace:(NSString *)spaceID;
- (void)clearShaderForSpace:(NSString *)spaceID;
- (NSDictionary<NSString *, NSString *> *)allAssignments;

// Per-Display Per-Space
- (nullable NSString *)shaderForSpace:(NSString *)spaceID display:(NSString *)displayID;
- (void)setShader:(NSString *)shaderName forSpace:(NSString *)spaceID display:(NSString *)displayID;

// Space Operations
- (void)assignCurrentShaderToCurrentSpace;
- (void)assignShaderToAllSpaces:(NSString *)shaderName;
- (void)copyAssignmentsFromSpace:(NSString *)sourceSpace toSpace:(NSString *)destSpace;

// Automatic Rotation
@property(nonatomic, assign) BOOL autoRotateEnabled;
@property(nonatomic, assign) NSTimeInterval rotationInterval;
- (void)startAutoRotation;
- (void)stopAutoRotation;

// Space Change Handling
- (void)handleSpaceChange;
- (void)refreshCurrentAssignments;

@end

NS_ASSUME_NONNULL_END
