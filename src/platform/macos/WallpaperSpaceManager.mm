//
//  WallpaperSpaceManager.mm
//  ShaderCandy
//
//  Manages wallpaper assignments per Space on macOS
//

#import "WallpaperSpaceManager.h"
#import "WallpaperEngine.h"
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

@interface WallpaperSpaceManager ()

// Data storage
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *spaceAssignments;  // spaceID -> shader
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSString *> *> *displaySpaceAssignments;  // displayID -> (spaceID -> shader)
@property(nonatomic, strong) NSMutableArray<NSString *> *knownSpaceIDs;

// State
@property(nonatomic, strong, nullable) NSString *currentSpaceID;
@property(nonatomic, strong, nullable) NSString *currentSpaceUUID;
@property(nonatomic, assign) BOOL autoRotateEnabled;
@property(nonatomic, assign) NSTimeInterval rotationInterval;

// Timer
@property(nonatomic, strong, nullable) NSTimer *rotationTimer;
@property(nonatomic, assign) NSInteger rotationIndex;

@end

@implementation WallpaperSpaceManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static WallpaperSpaceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WallpaperSpaceManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _spaceAssignments = [NSMutableDictionary dictionary];
        _displaySpaceAssignments = [NSMutableDictionary dictionary];
        _knownSpaceIDs = [NSMutableArray array];
        _autoRotateEnabled = NO;
        _rotationInterval = 300.0;  // 5 minutes
        _rotationIndex = 0;
        
        [self refreshSpaces];
        [self setupNotifications];
    }
    return self;
}

- (void)dealloc {
    [self stopAutoRotation];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(spaceDidChange:)
                                                 name:NSWorkspaceActiveSpaceDidChangeNotification
                                               object:nil];
}

- (void)refreshSpaces {
    // Get all available spaces
    // Note: Direct space access is limited in modern macOS
    // We track spaces as we encounter them
    
    // Add current space if not known
    NSString *currentSpace = [self getCurrentSpaceID];
    if (currentSpace && ![_knownSpaceIDs containsObject:currentSpace]) {
        [_knownSpaceIDs addObject:currentSpace];
    }
    
    _currentSpaceID = currentSpace;
    _currentSpaceUUID = [self getCurrentSpaceUUID];
}

- (NSString *)getCurrentSpaceID {
    // Use CGWindow for space information
    CGWindowID windowID = (CGWindowID)[NSApp mainWindow].windowNumber;
    
    // Try to get space from window
    CFArrayRef windowIDs = CFArrayCreate(kCFAllocatorDefault, (const void **)&windowID, 1, NULL);
    CFArrayRef windowInfos = CGWindowCreateDescriptionFromArray(windowIDs);
    
    if (windowInfos && CFArrayGetCount(windowInfos) > 0) {
        NSDictionary *windowInfo = (__bridge NSDictionary *)CFArrayGetValueAtIndex(windowInfos, 0);
        NSString *spaceID = windowInfo[(id)kCGWindowWorkspace];
        
        CFRelease(windowInfos);
        CFRelease(windowIDs);
        
        return spaceID ?: @"Default";
    }
    
    if (windowInfos) CFRelease(windowInfos);
    if (windowIDs) CFRelease(windowIDs);
    
    return @"Default";
}

- (NSString *)getCurrentSpaceUUID {
    // Generate a unique identifier for the current space configuration
    // This changes when spaces are added/removed or rearranged
    NSMutableString *uuid = [NSMutableString string];
    
    // Include display configuration
    NSArray *screens = [NSScreen screens];
    for (NSScreen *screen in screens) {
        [uuid appendFormat:@"%@", screen.deviceDescription[@"NSScreenNumber"]];
    }
    
    return [uuid copy];
}

#pragma mark - Space Management

- (NSArray<NSString *> *)allSpaceIDs {
    return [_knownSpaceIDs copy];
}

- (NSString *)currentSpaceID {
    if (!_currentSpaceID) {
        [self refreshSpaces];
    }
    return _currentSpaceID ?: @"Default";
}

- (NSString *)currentSpaceUUID {
    return _currentSpaceUUID ?: @"";
}

#pragma mark - Assignment Management

- (NSString *)shaderForSpace:(NSString *)spaceID {
    // First check per-display assignments
    NSString *primaryDisplay = @"Display1";
    NSString *displayShader = _displaySpaceAssignments[primaryDisplay][spaceID];
    if (displayShader) {
        return displayShader;
    }
    
    // Fall back to general space assignment
    return _spaceAssignments[spaceID] ?: @"plasma";
}

- (void)setShader:(NSString *)shaderName forSpace:(NSString *)spaceID {
    _spaceAssignments[spaceID] = shaderName;
    
    // Also set for all displays
    for (NSString *displayID in _displaySpaceAssignments.allKeys) {
        _displaySpaceAssignments[displayID][spaceID] = shaderName;
    }
    
    // Apply if this is the current space
    if ([spaceID isEqualToString:self.currentSpaceID]) {
        [[WallpaperEngine sharedEngine] switchToShader:shaderName];
    }
    
    [self saveAssignments];
}

- (void)clearShaderForSpace:(NSString *)spaceID {
    [_spaceAssignments removeObjectForKey:spaceID];
    
    for (NSString *displayID in _displaySpaceAssignments.allKeys) {
        [_displaySpaceAssignments[displayID] removeObjectForKey:spaceID];
    }
    
    [self saveAssignments];
}

- (NSDictionary<NSString *, NSString *> *)allAssignments {
    return [_spaceAssignments copy];
}

#pragma mark - Per-Display Per-Space

- (NSString *)shaderForSpace:(NSString *)spaceID display:(NSString *)displayID {
    // Ensure display entry exists
    if (!_displaySpaceAssignments[displayID]) {
        _displaySpaceAssignments[displayID] = [NSMutableDictionary dictionary];
    }
    
    return _displaySpaceAssignments[displayID][spaceID] ?: _spaceAssignments[spaceID] ?: @"plasma";
}

- (void)setShader:(NSString *)shaderName forSpace:(NSString *)spaceID display:(NSString *)displayID {
    // Ensure display entry exists
    if (!_displaySpaceAssignments[displayID]) {
        _displaySpaceAssignments[displayID] = [NSMutableDictionary dictionary];
    }
    
    _displaySpaceAssignments[displayID][spaceID] = shaderName;
    
    // Apply if this is the current space and display
    if ([spaceID isEqualToString:self.currentSpaceID]) {
        [[WallpaperEngine sharedEngine] setWallpaperForDesktop:displayID withShader:shaderName];
    }
    
    [self saveAssignments];
}

#pragma mark - Space Operations

- (void)assignCurrentShaderToCurrentSpace {
    NSString *currentShader = [WallpaperEngine sharedEngine].currentShader;
    if (currentShader) {
        [self setShader:currentShader forSpace:self.currentSpaceID];
    }
}

- (void)assignShaderToAllSpaces:(NSString *)shaderName {
    for (NSString *spaceID in _knownSpaceIDs) {
        [self setShader:shaderName forSpace:spaceID];
    }
}

- (void)copyAssignmentsFromSpace:(NSString *)sourceSpace toSpace:(NSString *)destSpace {
    NSString *shader = _spaceAssignments[sourceSpace];
    if (shader) {
        [self setShader:shader forSpace:destSpace];
    }
}

#pragma mark - Auto Rotation

- (void)startAutoRotation {
    if (_rotationTimer) return;
    
    _autoRotateEnabled = YES;
    _rotationIndex = 0;
    
    NSArray *shaders = @[@"plasma", @"mandelbulb_3d", @"nebula", @"vortex", @"tunnel"];
    
    _rotationTimer = [NSTimer scheduledTimerWithTimeInterval:_rotationInterval
                                                       target:self
                                                     selector:@selector(autoRotateTimer:)
                                                     userInfo:shaders
                                                      repeats:YES];
}

- (void)stopAutoRotation {
    [_rotationTimer invalidate];
    _rotationTimer = nil;
    _autoRotateEnabled = NO;
}

- (void)autoRotateTimer:(NSTimer *)timer {
    NSArray *shaders = timer.userInfo;
    
    if (shaders.count == 0) return;
    
    // Rotate shader for current space
    _rotationIndex = (_rotationIndex + 1) % shaders.count;
    NSString *nextShader = shaders[_rotationIndex];
    
    [self setShader:nextShader forSpace:self.currentSpaceID];
}

#pragma mark - Space Change Handling

- (void)spaceDidChange:(NSNotification *)notification {
    [self handleSpaceChange];
}

- (void)handleSpaceChange {
    NSString *oldSpaceID = _currentSpaceID;
    NSString *oldSpaceUUID = _currentSpaceUUID;
    
    [self refreshSpaces];
    
    NSString *newShader = [self shaderForSpace:self.currentSpaceID];
    
    // Only switch if space actually changed
    if (![oldSpaceID isEqualToString:_currentSpaceID] || 
        ![oldSpaceUUID isEqualToString:_currentSpaceUUID]) {
        
        [[WallpaperEngine sharedEngine] switchToShader:newShader];
        
        NSLog(@"Wallpaper: Changed to space %@, shader: %@", _currentSpaceID, newShader);
    }
}

- (void)refreshCurrentAssignments {
    // Refresh space info and apply current assignment
    NSString *shader = [self shaderForSpace:self.currentSpaceID];
    [[WallpaperEngine sharedEngine] switchToShader:shader];
}

#pragma mark - Persistence

- (NSString *)storagePath {
    NSString *appSupport = [@"~/Library/Application Support/ShaderCandy" stringByExpandingTildeInPath];
    return [appSupport stringByAppendingPathComponent:@"space_assignments.json"];
}

- (void)saveAssignments {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    // Save space assignments
    data[@"spaces"] = _spaceAssignments;
    
    // Save display-specific assignments
    NSMutableDictionary *displayData = [NSMutableDictionary dictionary];
    for (NSString *displayID in _displaySpaceAssignments) {
        displayData[displayID] = _displaySpaceAssignments[displayID];
    }
    data[@"displays"] = displayData;
    
    // Save known space IDs
    data[@"knownSpaces"] = _knownSpaceIDs;
    
    // Save auto-rotate settings
    data[@"autoRotateEnabled"] = @(_autoRotateEnabled);
    data[@"rotationInterval"] = @(_rotationInterval);
    
    // Serialize to JSON
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (jsonData) {
        [jsonData writeToFile:[self storagePath] atomically:YES];
    } else {
        NSLog(@"Failed to save space assignments: %@", error);
    }
}

- (void)loadAssignments {
    NSString *path = [self storagePath];
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    if (!jsonData) return;
    
    NSError *error = nil;
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:0
                                                           error:&error];
    if (error || ![data isKindOfClass:[NSDictionary class]]) return;
    
    // Load space assignments
    NSDictionary *spaces = data[@"spaces"];
    if ([spaces isKindOfClass:[NSDictionary class]]) {
        [_spaceAssignments addEntriesFromDictionary:spaces];
    }
    
    // Load display-specific assignments
    NSDictionary *displays = data[@"displays"];
    if ([displays isKindOfClass:[NSDictionary class]]) {
        for (NSString *displayID in displays) {
            NSDictionary *spaceAssignments = displays[displayID];
            if ([spaceAssignments isKindOfClass:[NSDictionary class]]) {
                _displaySpaceAssignments[displayID] = [spaceAssignments mutableCopy];
            }
        }
    }
    
    // Load known space IDs
    NSArray *knownSpaces = data[@"knownSpaces"];
    if ([knownSpaces isKindOfClass:[NSArray class]]) {
        [_knownSpaceIDs addObjectsFromArray:knownSpaces];
    }
    
    // Load auto-rotate settings
    NSNumber *autoRotate = data[@"autoRotateEnabled"];
    if (autoRotate) {
        _autoRotateEnabled = autoRotate.boolValue;
        if (_autoRotateEnabled) {
            [self startAutoRotation];
        }
    }
    
    NSNumber *interval = data[@"rotationInterval"];
    if (interval) {
        _rotationInterval = interval.doubleValue;
    }
}

@end
