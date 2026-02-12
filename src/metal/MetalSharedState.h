#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Shared state for synchronizing multiple renderer instances (Multi-Monitor)
 */
@interface MetalSharedState : NSObject

@property(nonatomic, strong, readonly) NSDate *referenceDate;
@property(nonatomic, assign) NSInteger globalParticleCount;
@property(nonatomic, assign) BOOL isScalingDown;

+ (instancetype)sharedState;

/**
 * Get synchronized time since screensaver started
 */
- (NSTimeInterval)synchronizedTime;

/**
 * Synchronize particle count across all monitors
 * Returns the smoothed value according to current budget
 */
- (NSInteger)syncParticleCount:(NSInteger)localCount;

@end

NS_ASSUME_NONNULL_END
