//
//  SpatialSoundscapeGenerator.h
//  ShaderCandy
//
//  Spatial audio generator with ray-traced acoustics
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

@class RayAudioEngine;
@class AcousticSimulator;

@interface SpatialSoundscapeGenerator : NSObject

@property(nonatomic, assign) BOOL binauralEnabled;
@property(nonatomic, assign) float reverbIntensity;
@property(nonatomic, assign) float roomSize;
@property(nonatomic, assign) float roomDamping;
@property(nonatomic, assign) float visualComplexity;
@property(nonatomic, strong, readonly) NSArray<NSDictionary *> *activeSources;

+ (instancetype)sharedGenerator;

- (BOOL)initializeWithSampleRate:(double)sampleRate error:(NSError **)error;
- (void)shutdown;

- (void)setVisualComplexity:(float)complexity;
- (void)updateSourcePositionsFromVisuals:(NSArray<NSValue *> *)visualPositions;

- (void)renderStereoOutputLeft:(float *)leftBuffer right:(float *)rightBuffer frameCount:(NSUInteger)frameCount;

- (void)addAmbientDroneWithFrequency:(float)frequency gain:(float)gain;
- (void)removeAmbientDrone;

- (void)setReverbParameters:(float)roomSize damping:(float)damping intensity:(float)intensity;

@end

@interface AcousticMaterialLibrary : NSObject

+ (instancetype)sharedLibrary;

- (float)absorptionForMaterial:(NSString *)materialName;
- (float)scatteringForMaterial:(NSString *)materialName;
- (void)registerMaterial:(NSString *)name absorption:(float)absorption scattering:(float)scattering;

@property(nonatomic, strong, readonly) NSArray<NSString *> *availableMaterials;

@end
