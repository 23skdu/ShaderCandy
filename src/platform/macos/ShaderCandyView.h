//
//  ShaderCandyView.h
//  ShaderCandy
//
//  macOS Screen Saver Implementation (Thin Adapter)
//

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <ScreenSaver/ScreenSaver.h>

NS_ASSUME_NONNULL_BEGIN

@class MetalRenderer;

@interface ShaderCandyView : ScreenSaverView <MTKViewDelegate>

// Principal Renderer
@property(nonatomic, strong, readonly, nullable) MetalRenderer *renderer;

// Configuration and State (Principally managed via Renderer, but mirrored for
// UI/Cycling)
@property(nonatomic, strong, nullable) NSString *currentShaderName;
@property(nonatomic, strong, nullable) NSArray<NSString *> *availableShaders;

// Screen Saver Parameters
@property(nonatomic, assign) NSInteger preferredFPS;
@property(nonatomic, assign) float speed;
@property(nonatomic, assign) float intensity;
@property(nonatomic, assign) float gravity;
@property(nonatomic, assign) BOOL enableBloom;
@property(nonatomic, assign) BOOL enableHotReload;

// UI
@property(nonatomic, strong, nullable) NSWindow *configPanel;

@end

NS_ASSUME_NONNULL_END
