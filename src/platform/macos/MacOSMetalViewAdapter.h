//
//  MacOSMetalViewAdapter.h
//  ShaderCandy
//
//  Thin delegation layer between ScreenSaverView and MetalRenderer
//

#import <ScreenSaver/ScreenSaver.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MetalRenderer;

@interface MacOSMetalViewAdapter : ScreenSaverView <MTKViewDelegate>

@property(nonatomic, strong, readonly, nullable) MetalRenderer *renderer;
@property(nonatomic, assign) BOOL enableBloom;
@property(nonatomic, assign) float speed;
@property(nonatomic, assign) float intensity;
@property(nonatomic, assign) float gravity;
@property(nonatomic, assign) NSInteger preferredFPS;
@property(nonatomic, assign) BOOL enableHotReload;

- (void)loadShaders;
- (void)reloadShaders;
- (void)selectShaderNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
