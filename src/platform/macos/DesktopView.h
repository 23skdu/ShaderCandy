//
//  DesktopView.h
//  ShaderCandy
//
//  Borderless view for rendering wallpaper on a display
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@class MetalRenderer;

@interface DesktopView : NSView

@property(nonatomic, strong, readonly, nullable) NSString *displayID;
@property(nonatomic, strong, readonly, nullable) NSString *currentShader;
@property(nonatomic, assign, readonly) BOOL isRendering;
@property(nonatomic, assign, readonly) BOOL isPaused;

- (instancetype)initWithFrame:(NSRect)frame
                     displayID:(NSString *)displayID
                        device:(id<MTLDevice>)device;

- (void)setShader:(nullable NSString *)shaderName renderer:(nullable MetalRenderer *)renderer;
- (void)startRendering;
- (void)stopRendering;
- (void)pauseRendering;
- (void)resumeRendering;

@end

NS_ASSUME_NONNULL_END
