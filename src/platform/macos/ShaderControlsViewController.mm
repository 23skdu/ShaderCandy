#import "ShaderControlsViewController.h"

@implementation ShaderControlsViewController

- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 300)];
  self.view.wantsLayer = YES;
  self.view.layer.backgroundColor =
      [NSColor colorWithWhite:0.1 alpha:0.8].CGColor;

  CGFloat padding = 20.0;
  CGFloat width = 160.0;
  CGFloat y = 250.0;

  // Title
  NSTextField *titleLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, width, 24)];
  titleLabel.stringValue = @"Shader Controls";
  titleLabel.font = [NSFont boldSystemFontOfSize:14];
  titleLabel.textColor = [NSColor whiteColor];
  titleLabel.editable = NO;
  titleLabel.bordered = NO;
  titleLabel.backgroundColor = [NSColor clearColor];
  [self.view addSubview:titleLabel];

  y -= 40;

  // Speed
  NSTextField *speedLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, width, 20)];
  speedLabel.stringValue = @"Speed";
  speedLabel.textColor = [NSColor lightGrayColor];
  speedLabel.editable = NO;
  speedLabel.bordered = NO;
  speedLabel.backgroundColor = [NSColor clearColor];
  [self.view addSubview:speedLabel];

  y -= 25;
  _speedSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(padding, y, width, 24)];
  _speedSlider.minValue = 0.0;
  _speedSlider.maxValue = 2.0;
  _speedSlider.target = self;
  _speedSlider.action = @selector(parameterChanged:);
  _speedSlider.identifier = @"speed";
  [self.view addSubview:_speedSlider];

  y -= 40;

  // Intensity
  NSTextField *intensityLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(padding, y, width, 20)];
  intensityLabel.stringValue = @"Intensity";
  intensityLabel.textColor = [NSColor lightGrayColor];
  intensityLabel.editable = NO;
  intensityLabel.bordered = NO;
  intensityLabel.backgroundColor = [NSColor clearColor];
  [self.view addSubview:intensityLabel];

  y -= 25;
  _intensitySlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(padding, y, width, 24)];
  _intensitySlider.minValue = 0.0;
  _intensitySlider.maxValue = 2.0;
  _intensitySlider.target = self;
  _intensitySlider.action = @selector(parameterChanged:);
  _intensitySlider.identifier = @"intensity";
  [self.view addSubview:_intensitySlider];

  y -= 40;

  // Bloom
  _bloomCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(padding, y, width, 24)];
  _bloomCheckbox.buttonType = NSButtonTypeSwitch;
  _bloomCheckbox.title = @"Enable Bloom";
  _bloomCheckbox.target = self;
  _bloomCheckbox.action = @selector(parameterChanged:);
  _bloomCheckbox.identifier = @"bloom";
  [self.view addSubview:_bloomCheckbox];
}

- (void)parameterChanged:(id)sender {
  if (self.onParameterChanged) {
    NSControl *control = (NSControl *)sender;
    float value = 0;
    if ([control isKindOfClass:[NSSlider class]]) {
      value = [(NSSlider *)control floatValue];
    } else if ([control isKindOfClass:[NSButton class]]) {
      value =
          [(NSButton *)control state] == NSControlStateValueOn ? 1.0f : 0.0f;
    }
    self.onParameterChanged(control.identifier, value);
  }
}

- (void)updateWithSpeed:(float)speed
              intensity:(float)intensity
                  bloom:(BOOL)bloom {
  self.speedSlider.floatValue = speed;
  self.intensitySlider.floatValue = intensity;
  self.bloomCheckbox.state =
      bloom ? NSControlStateValueOn : NSControlStateValueOff;
}

@end
