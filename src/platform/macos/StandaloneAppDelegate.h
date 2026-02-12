#import "../../metal/MetalRenderer.h"
#import "StandaloneAppWindowController.h"

@interface StandaloneAppDelegate
    : NSObject <NSApplicationDelegate, MTKViewDelegate,
                StandaloneAppWindowControllerDelegate>

@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) MTKView *metalView;
@property(nonatomic, strong) MetalRenderer *renderer;
@property(nonatomic, strong) NSTimer *updateTimer;
@property(nonatomic, strong) StandaloneAppWindowController *windowController;

// Configuration
@property(nonatomic, assign) float speed;
@property(nonatomic, assign) float intensity;
@property(nonatomic, assign) float gravity;
@property(nonatomic, assign) NSInteger preferredFPS;
@property(nonatomic, strong) NSString *currentShader;

// Timing
@property(nonatomic, strong) NSDate *startTime;

@end
