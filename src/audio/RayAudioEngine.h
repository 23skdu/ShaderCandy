//
//  RayAudioEngine.h
//  ShaderCandy
//
//  Audio ray tracing engine for spatial audio
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

@interface RayAudioEngine : NSObject

@property(nonatomic, strong, readonly, nullable) id<MTLDevice> device;
@property(nonatomic, assign, readonly) double sampleRate;
@property(nonatomic, assign, readonly) BOOL isRunning;
@property(nonatomic, assign) simd_float3 listenerPosition;
@property(nonatomic, assign) simd_float3 listenerOrientation;
@property(nonatomic, assign) float globalGain;
@property(nonatomic, assign) int maxRays;

+ (instancetype _Nonnull)sharedEngine;

- (BOOL)initializeWithSampleRate:(double)sampleRate error:(NSError * _Nullable * _Null_unspecified)error;
- (void)shutdown;

- (void)start;
- (void)stop;

- (void)setAudioSource:(NSInteger)sourceID position:(simd_float3)position;
- (void)setAudioSource:(NSInteger)sourceID frequency:(float)frequency;
- (void)setAudioSource:(NSInteger)sourceID gain:(float)gain;
- (void)removeAudioSource:(NSInteger)sourceID;

- (void)processAudioBuffer:(float * _Nonnull)buffer frameCount:(NSUInteger)frameCount;
- (void)processStereoBuffer:(float * _Nonnull)leftBuffer right:(float * _Nonnull)rightBuffer frameCount:(NSUInteger)frameCount;

- (void)setSceneGeometry:(id<MTLTexture> _Nullable)geometryTexture;
- (void)updateRayTracing;

@end
