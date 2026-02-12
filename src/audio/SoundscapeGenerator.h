#pragma once

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Soundscape types
 */
typedef NS_ENUM(NSInteger, SoundscapeType) {
  SoundscapeTypeNone,
  SoundscapeTypeCosmicDrone, // Deep humming, spacey
  SoundscapeTypeDigitalWind, // Modulated noise, ethereal
};

/**
 * Performance metrics for audio modulation
 */
typedef struct {
  float intensity;        // 0-1
  float speed;            // 0.1-5.0
  float visualComplexity; // e.g. particle count or bloom level
  float activity;         // e.g. mouse movement delta
} SoundscapeMetrics;

@interface SoundscapeGenerator : NSObject

@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, assign) float masterVolume;
@property(nonatomic, assign) SoundscapeType activeType;

+ (instancetype)sharedGenerator;

/**
 * Start the audio engine
 */
- (BOOL)start;

/**
 * Stop the audio engine
 */
- (void)stop;

/**
 * Update audio parameters based on visual metrics
 */
- (void)updateWithMetrics:(SoundscapeMetrics)metrics;

/**
 * Select a soundscape preset
 */
- (void)transitionToSoundscape:(SoundscapeType)type
                      duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
