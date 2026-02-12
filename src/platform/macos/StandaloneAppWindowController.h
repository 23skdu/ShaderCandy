//
//  StandaloneAppWindowController.h
//  ShaderCandy
//
//  Window controller for the standalone player application
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MetalRenderer;
@class MetalRendererError;

@protocol StandaloneAppWindowControllerDelegate <NSObject>

@optional
- (void)windowController:(id)controller didSelectShader:(NSString *)shaderName;
- (void)windowController:(id)controller didUpdateMetrics:(NSDictionary *)metrics;
- (void)windowController:(id)controller didEncounterError:(MetalRendererError *)error;

@end

@interface StandaloneAppWindowController : NSWindowController <NSWindowDelegate>

// Properties
@property(nonatomic, strong, nullable) MTKView *metalView;
@property(nonatomic, strong, nullable) MetalRenderer *renderer;
@property(nonatomic, weak, nullable) id<StandaloneAppWindowControllerDelegate> delegate;

// UI Elements
@property(nonatomic, strong, nullable) NSView *shaderListContainer;
@property(nonatomic, strong, nullable) NSView *metricsContainer;
@property(nonatomic, strong, nullable) NSTextField *shaderNameLabel;
@property(nonatomic, strong, nullable) NSTextField *fpsLabel;
@property(nonatomic, strong, nullable) NSButton *fullScreenButton;
@property(nonatomic, strong, nullable) NSButton *settingsButton;

// State
@property(nonatomic, strong, nullable) NSString *currentShader;
@property(nonatomic, strong) NSArray<NSString *> *availableShaders;
@property(nonatomic, assign) NSInteger currentShaderIndex;
@property(nonatomic, assign) BOOL showingShaderList;
@property(nonatomic, assign) BOOL showingMetrics;

// Initialization
- (instancetype _Nullable)initWithWindow:(NSWindow * _Nullable)window;
- (instancetype)initWithWindowNibName:(NSString *)nibName;

// Shader Management
- (void)selectShader:(NSString *)shaderName;
- (void)selectShaderAtIndex:(NSInteger)index;
- (void)nextShader;
- (void)previousShader;

// UI Updates
- (void)setupWindow;
- (void)setupToolbar;
- (void)setupShaderList;
- (void)setupMetricsDisplay;

// Callbacks
- (void)onShaderSelected:(NSString *)shaderName;
- (void)onMetricsUpdated:(NSDictionary *)metrics;

@end

NS_ASSUME_NONNULL_END
