#import "../../metal/MetalRenderer.h"
#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

@interface StandaloneAppDelegate
    : NSObject <NSApplicationDelegate, MTKViewDelegate>

@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) MTKView *metalView;
@property(nonatomic, strong) MetalRenderer *renderer;
@property(nonatomic, strong) NSTimer *updateTimer;

// Configuration
@property(nonatomic, assign) float speed;
@property(nonatomic, assign) float intensity;
@property(nonatomic, assign) float gravity;
@property(nonatomic, assign) NSInteger preferredFPS;
@property(nonatomic, strong) NSString *currentShader;

@end
