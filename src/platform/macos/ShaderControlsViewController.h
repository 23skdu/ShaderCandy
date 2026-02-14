#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShaderControlsViewController : NSViewController

@property(nonatomic, strong) NSSlider *speedSlider;
@property(nonatomic, strong) NSSlider *intensitySlider;
@property(nonatomic, strong) NSButton *bloomCheckbox;

@property(nonatomic, copy, nullable) void (^onParameterChanged)
    (NSString *name, float value);

- (void)updateWithSpeed:(float)speed
              intensity:(float)intensity
                  bloom:(BOOL)bloom;

@end

NS_ASSUME_NONNULL_END
