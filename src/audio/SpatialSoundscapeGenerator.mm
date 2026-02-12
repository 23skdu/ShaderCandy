//
//  SpatialSoundscapeGenerator.mm
//  ShaderCandy
//
//  Spatial soundscape implementation
//

#import "SpatialSoundscapeGenerator.h"
#import "RayAudioEngine.h"
#import "AcousticSimulator.h"
#import <Accelerate/Accelerate.h>

@interface SpatialSoundscapeGenerator ()

@property(nonatomic, strong) RayAudioEngine *audioEngine;
@property(nonatomic, strong) AcousticSimulator *acousticSimulator;
@property(nonatomic, assign) double sampleRate;
@property(nonatomic, assign) BOOL isInitialized;
@property(nonatomic, assign) float droneFrequency;
@property(nonatomic, assign) float droneGain;
@property(nonatomic, assign) float dronePhase;
@property(nonatomic, assign) BOOL hasDrone;
@property(nonatomic, strong) NSMutableArray *sourcePositions;
@property(nonatomic, strong) dispatch_queue_t audioQueue;

@end

@implementation SpatialSoundscapeGenerator

+ (instancetype)sharedGenerator {
    static SpatialSoundscapeGenerator *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SpatialSoundscapeGenerator alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _binauralEnabled = YES;
        _reverbIntensity = 0.3;
        _roomSize = 10.0;
        _roomDamping = 0.5;
        _visualComplexity = 0.5;
        _sampleRate = 48000.0;
        _hasDrone = NO;
        _droneFrequency = 110.0;
        _droneGain = 0.3;
        _sourcePositions = [NSMutableArray array];
        _audioQueue = dispatch_queue_create("com.shadercandy.soundscape", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)initializeWithSampleRate:(double)sampleRate error:(NSError **)error {
    if (_isInitialized) return YES;

    _sampleRate = sampleRate;

    _audioEngine = [RayAudioEngine sharedEngine];
    BOOL success = [_audioEngine initializeWithSampleRate:sampleRate error:error];
    if (!success) return NO;

    _acousticSimulator = [AcousticSimulator sharedSimulator];
    [_acousticSimulator initializeWithDevice:_audioEngine.device error:error];

    _isInitialized = YES;
    [_audioEngine start];

    return YES;
}

- (void)shutdown {
    [_audioEngine stop];
    _isInitialized = NO;
}

- (void)setVisualComplexity:(float)complexity {
    _visualComplexity = complexity;

    // Adjust audio parameters based on visual complexity
    _roomDamping = 0.3 + complexity * 0.4;
    _reverbIntensity = 0.2 + complexity * 0.3;

    // Update number of sources based on complexity
    int numSources = (int)(complexity * 5) + 1;
    [self updateSourceCount:numSources];
}

- (void)updateSourceCount:(int)count {
    // Add or remove sources to match count
    for (int i = 0; i < count; i++) {
        float angle = (float)i / count * 2.0 * M_PI;
        float radius = 2.0 + _visualComplexity * 3.0;
        simd_float3 pos = simd_make_float3(cos(angle) * radius, sin(angle) * 0.5, sin(angle) * radius);

        [_audioEngine setAudioSource:i position:pos];
        [_audioEngine setAudioSource:i frequency:110.0 * (i + 1) * 0.5];
        [_audioEngine setAudioSource:i gain:0.1 / (i + 1)];
    }
}

- (void)updateSourcePositionsFromVisuals:(NSArray<NSValue *> *)visualPositions {
    int index = 0;
    for (NSValue *value in visualPositions) {
        simd_float3 pos;
        [value getValue:&pos];
        [_audioEngine setAudioSource:index position:pos];
        index++;
    }
}

- (void)renderStereoOutputLeft:(float *)leftBuffer right:(float *)rightBuffer frameCount:(NSUInteger)frameCount {
    if (!_isInitialized) {
        memset(leftBuffer, 0, frameCount * sizeof(float));
        memset(rightBuffer, 0, frameCount * sizeof(float));
        return;
    }

    // Generate drone if enabled
    if (_hasDrone) {
        [self addDroneToBuffersLeft:leftBuffer right:rightBuffer frameCount:frameCount];
    }

    // Add spatial audio from ray-traced sources
    float tempLeft[frameCount];
    float tempRight[frameCount];

    [_audioEngine processStereoBuffer:tempLeft right:tempRight frameCount:frameCount];

    // Mix with drone
    for (NSUInteger i = 0; i < frameCount; i++) {
        leftBuffer[i] += tempLeft[i] * _reverbIntensity;
        rightBuffer[i] += tempRight[i] * _reverbIntensity;
    }

    // Apply room acoustics simulation
    [self applyRoomAcousticsLeft:leftBuffer right:rightBuffer frameCount:frameCount];
}

- (void)addDroneToBuffersLeft:(float *)leftBuffer right:(float *)rightBuffer frameCount:(NSUInteger)frameCount {
    float phaseIncrement = 2.0 * M_PI * _droneFrequency / _sampleRate;

    for (NSUInteger i = 0; i < frameCount; i++) {
        // Create a rich drone with multiple harmonics
        float sample = 0.0;
        sample += sin(_dronePhase) * 0.5;
        sample += sin(_dronePhase * 2.0) * 0.25;
        sample += sin(_dronePhase * 3.0) * 0.125;

        sample *= _droneGain;

        leftBuffer[i] += sample;
        rightBuffer[i] += sample;

        _dronePhase += phaseIncrement;
        if (_dronePhase > 2.0 * M_PI) {
            _dronePhase -= 2.0 * M_PI;
        }
    }
}

- (void)applyRoomAcousticsLeft:(float *)leftBuffer right:(float *)rightBuffer frameCount:(NSUInteger)frameCount {
    // Simple reverb simulation
    static float reverbBufferL[48000] = {0};
    static float reverbBufferR[48000] = {0};
    static int reverbIndex = 0;

    int delaySamples = (int)(_roomSize * _sampleRate / 343.0); // Speed of sound

    for (NSUInteger i = 0; i < frameCount; i++) {
        int readIndex = (reverbIndex - delaySamples + 48000) % 48000;

        float reverbL = reverbBufferL[readIndex] * _roomDamping;
        float reverbR = reverbBufferR[readIndex] * _roomDamping;

        reverbBufferL[reverbIndex] = leftBuffer[i] + reverbL * 0.5;
        reverbBufferR[reverbIndex] = rightBuffer[i] + reverbR * 0.5;

        leftBuffer[i] = leftBuffer[i] * 0.7 + reverbL * _reverbIntensity;
        rightBuffer[i] = rightBuffer[i] * 0.7 + reverbR * _reverbIntensity;

        reverbIndex = (reverbIndex + 1) % 48000;
    }
}

- (void)addAmbientDroneWithFrequency:(float)frequency gain:(float)gain {
    _droneFrequency = frequency;
    _droneGain = gain;
    _hasDrone = YES;
}

- (void)removeAmbientDrone {
    _hasDrone = NO;
}

- (void)setReverbParameters:(float)roomSize damping:(float)damping intensity:(float)intensity {
    _roomSize = roomSize;
    _roomDamping = damping;
    _reverbIntensity = intensity;
}

- (NSArray<NSDictionary *> *)activeSources {
    NSMutableArray *sources = [NSMutableArray array];
    // Return info about active audio sources
    return sources;
}

@end

@implementation AcousticMaterialLibrary

+ (instancetype)sharedLibrary {
    static AcousticMaterialLibrary *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AcousticMaterialLibrary alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self registerDefaultMaterials];
    }
    return self;
}

- (void)registerDefaultMaterials {
    [self registerMaterial:@"Concrete" absorption:0.02 scattering:0.1];
    [self registerMaterial:@"Glass" absorption:0.05 scattering:0.3];
    [self registerMaterial:@"Fabric" absorption:0.6 scattering:0.5];
    [self registerMaterial:@"Wood" absorption:0.1 scattering:0.2];
    [self registerMaterial:@"Water" absorption:0.02 scattering:0.05];
    [self registerMaterial:@"Metal" absorption:0.05 scattering:0.4];
    [self registerMaterial:@"Carpet" absorption:0.4 scattering:0.3];
}

- (void)registerMaterial:(NSString *)name absorption:(float)absorption scattering:(float)scattering {
    // Store material properties
}

- (float)absorptionForMaterial:(NSString *)materialName {
    NSDictionary *materials = @{
        @"Concrete": @(0.02),
        @"Glass": @(0.05),
        @"Fabric": @(0.6),
        @"Wood": @(0.1),
        @"Water": @(0.02),
        @"Metal": @(0.05),
        @"Carpet": @(0.4)
    };
    return [materials[materialName] floatValue] ?: 0.3;
}

- (float)scatteringForMaterial:(NSString *)materialName {
    NSDictionary *materials = @{
        @"Concrete": @(0.1),
        @"Glass": @(0.3),
        @"Fabric": @(0.5),
        @"Wood": @(0.2),
        @"Water": @(0.05),
        @"Metal": @(0.4),
        @"Carpet": @(0.3)
    };
    return [materials[materialName] floatValue] ?: 0.2;
}

- (NSArray<NSString *> *)availableMaterials {
    return @[@"Concrete", @"Glass", @"Fabric", @"Wood", @"Water", @"Metal", @"Carpet"];
}

@end
