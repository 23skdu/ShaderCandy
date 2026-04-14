//
//  DesktopView.mm
//  ShaderCandy
//
//  Borderless view for rendering wallpaper on a display
//

#import "DesktopView.h"
#import "../../metal/MetalRenderer.h"

@interface DesktopView ()

// Rendering
@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) MetalRenderer *renderer;
@property(nonatomic, strong, nullable) CAMetalLayer *metalLayer;
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;

// State
@property(nonatomic, strong, nullable) NSString *shaderName;
@property(nonatomic, assign) BOOL isRendering;
@property(nonatomic, assign) BOOL isPaused;

// Time tracking
@property(nonatomic, assign) NSTimeInterval startTime;
@property(nonatomic, assign) NSInteger frameCount;

@end

@implementation DesktopView

- (instancetype)initWithFrame:(NSRect)frame
                     displayID:(NSString *)displayID
                        device:(id<MTLDevice>)device {
    self = [super initWithFrame:frame];
    if (self) {
        _displayID = displayID;
        _device = device;
        _isRendering = NO;
        _isPaused = NO;
        _frameCount = 0;
        _startTime = CACurrentMediaTime();
        
        [self setupMetalLayer];
    }
    return self;
}

- (void)dealloc {
    [self stopRendering];
}

#pragma mark - Setup

- (void)setupMetalLayer {
    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES;
    _metalLayer.frame = self.bounds;
    _metalLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    
    // Configure for wallpaper (no vsync, allow tearing)
    _metalLayer.displaySyncEnabled = NO;
    
    self.layer = _metalLayer;
    self.wantsLayer = YES;
}

- (void)layout {
    [super layout];
    
    // Update metal layer size
    if (_metalLayer) {
        _metalLayer.frame = self.bounds;
    }
}

#pragma mark - Shader Management

- (void)setShader:(NSString *)shaderName renderer:(MetalRenderer *)renderer {
    if (!renderer) {
        _shaderName = nil;
        _renderer = nil;
        return;
    }
    
    _renderer = renderer;
    
    // Load the shader if different
    if (!shaderName || ![shaderName isEqualToString:_shaderName]) {
        _shaderName = shaderName;
        
        if (shaderName) {
            NSError *error = nil;
            BOOL success = [renderer setActiveShader:shaderName error:&error];
            if (!success) {
                NSLog(@"Failed to load shader '%@': %@", shaderName, error);
                _shaderName = @"plasma";  // Fallback
                [renderer setActiveShader:_shaderName error:nil];
            }
        }
    }
}

#pragma mark - Rendering Control

- (void)startRendering {
    if (_isRendering || !_device || !_renderer) return;
    
    _isRendering = YES;
    _isPaused = NO;
    _frameCount = 0;
    _startTime = CACurrentMediaTime();
    
    // Create display link
    _displayLink = [CADisplayLink displayLinkWithTarget:self
                                               selector:@selector(displayLinkCallback:)];
    _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(20, 30, 30);
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopRendering {
    if (!_isRendering) return;
    
    _isRendering = NO;
    _isPaused = NO;
    
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)pauseRendering {
    if (!_isRendering || _isPaused) return;
    _isPaused = YES;
}

- (void)resumeRendering {
    if (!_isRendering || !_isPaused) return;
    _isPaused = NO;
}

#pragma mark - Display Link Callback

- (void)displayLinkCallback:(CADisplayLink *)displayLink {
    if (_isPaused || !_renderer) return;
    
    // Get drawable
    id<CAMetalDrawable> drawable = _metalLayer.nextDrawable;
    if (!drawable) return;
    
    // Update uniforms
    NSTimeInterval time = CACurrentMediaTime() - _startTime;
    
    CGSize size = self.bounds.size;
    [_renderer updateUniformsWithTime:time
                        mousePosition:NSMakePoint(0, 0)
                         mouseButtons:0
                                speed:1.0f
                            intensity:1.0f
                              gravity:0.0f
                               height:size.height];
    
    // Create render pass descriptor
    MTLRenderPassDescriptor *renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    
    // Render frame
    @try {
        [_renderer renderToDrawable:drawable renderPassDescriptor:renderPassDescriptor];
        _frameCount++;
    } @catch (NSException *exception) {
        NSLog(@"Rendering exception: %@", exception);
    }
}

#pragma mark - Properties

- (BOOL)isRendering {
    return _isRendering;
}

- (BOOL)isPaused {
    return _isPaused;
}

@end
