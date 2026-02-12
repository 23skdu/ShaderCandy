//
//  AcousticSimulator.h
//  ShaderCandy
//
//  Physics-based acoustic simulation using ray tracing
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

@interface AcousticSimulator : NSObject

@property(nonatomic, strong, readonly, nullable) id<MTLDevice> device;
@property(nonatomic, assign) int maxReflections;
@property(nonatomic, assign) float roomSize;
@property(nonatomic, assign) float absorption;
@property(nonatomic, assign) float scattering;
@property(nonatomic, assign) BOOL enableDoppler;
@property(nonatomic, assign) BOOL binauralEnabled;

+ (instancetype)sharedSimulator;

- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error;
- (void)shutdown;

- (void)setSceneGeometry:(id<MTLTexture>)geometryTexture;
- (void)setAudioSource:(simd_float3)position frequency:(float)hz;
- (void)setListenerPosition:(simd_float3)position;

- (id<MTLTexture>)renderAcousticField;
- (float)getEnergyAtPosition:(simd_float3)position;
- (float)getImpulseResponseAtPosition:(simd_float3)position time:(float)time;

- (void)simulateReflections;
- (void)updateSimulation:(float)deltaTime;

@end
