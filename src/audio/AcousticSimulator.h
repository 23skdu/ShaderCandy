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

+ (instancetype _Nonnull)sharedSimulator;

- (BOOL)initializeWithDevice:(id<MTLDevice> _Nonnull)device error:(NSError * _Nullable * _Null_unspecified)error;
- (void)shutdown;

- (void)setSceneGeometry:(id<MTLTexture> _Nullable)geometryTexture;
- (void)setAudioSource:(simd_float3)position frequency:(float)hz;
- (void)setListenerPosition:(simd_float3)position;

- (id<MTLTexture> _Nullable)renderAcousticField;
- (float)getEnergyAtPosition:(simd_float3)position;
- (float)getImpulseResponseAtPosition:(simd_float3)position time:(float)time;

- (void)simulateReflections;
- (void)updateSimulation:(float)deltaTime;

@end
