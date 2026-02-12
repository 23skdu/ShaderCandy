#import "MetalSharedState.h"

@implementation MetalSharedState

+ (instancetype)sharedState {
  static MetalSharedState *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[MetalSharedState alloc] init];
  });
  return shared;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _referenceDate = [NSDate date];
    _globalParticleCount = 10000; // Default
    _isScalingDown = NO;
  }
  return self;
}

- (NSTimeInterval)synchronizedTime {
  return [[NSDate date] timeIntervalSinceDate:self.referenceDate];
}

- (NSInteger)syncParticleCount:(NSInteger)localCount {
  // Basic shared logic: the lowest performing monitor sets the budget
  // for everyone to ensure uniform visuals
  @synchronized(self) {
    // If one monitor is scaling down, we all scale down
    if (localCount < _globalParticleCount) {
      _globalParticleCount = localCount;
    } else if (localCount > _globalParticleCount * 1.05) {
      // Gradually allow recovery if local wants more
      _globalParticleCount = (NSInteger)(_globalParticleCount * 1.01);
    }
    return _globalParticleCount;
  }
}

@end
