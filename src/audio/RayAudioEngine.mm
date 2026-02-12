//
//  RayAudioEngine.mm
//  ShaderCandy
//
//  Audio ray tracing implementation
//

#import "RayAudioEngine.h"
#import "AcousticSimulator.h"
#import <Accelerate/Accelerate.h>

@interface AudioSource : NSObject
@property(nonatomic, assign) NSInteger sourceID;
@property(nonatomic, assign) simd_float3 position;
@property(nonatomic, assign) float frequency;
@property(nonatomic, assign) float gain;
@property(nonatomic, assign) float phase;
@property(nonatomic, assign) BOOL isActive;
@end

@implementation AudioSource
@end

@interface RayAudioEngine ()

@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong, nullable) AcousticSimulator *acousticSimulator;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, AudioSource *> *audioSources;
@property(nonatomic, assign) double sampleRate;
@property(nonatomic, assign) BOOL isRunning;
@property(nonatomic, assign) double currentTime;
@property(nonatomic, strong) dispatch_queue_t audioQueue;

@end

@implementation RayAudioEngine

+ (instancetype)sharedEngine {
    static RayAudioEngine *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[RayAudioEngine alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _audioSources = [NSMutableDictionary dictionary];
        _sampleRate = 48000.0;
        _isRunning = NO;
        _currentTime = 0.0;
        _globalGain = 1.0;
        _maxRays = 256;
        _listenerPosition = simd_make_float3(0, 0, 0);
        _listenerOrientation = simd_make_float3(0, 0, 1);
        _audioQueue = dispatch_queue_create("com.shadercandy.audio", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)initializeWithSampleRate:(double)sampleRate error:(NSError **)error {
    _sampleRate = sampleRate;

    // Get Metal device
    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        if (error) {
            *error = [NSError errorWithDomain:@"RayAudioEngine" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Metal not available"}];
        }
        return NO;
    }

    _commandQueue = [_device newCommandQueue];

    // Initialize acoustic simulator
    _acousticSimulator = [AcousticSimulator sharedSimulator];
    BOOL success = [_acousticSimulator initializeWithDevice:_device error:error];

    return success;
}

- (void)shutdown {
    [self stop];
    _acousticSimulator = nil;
    _commandQueue = nil;
    _device = nil;
}

- (void)start {
    _isRunning = YES;
}

- (void)stop {
    _isRunning = NO;
}

- (void)setAudioSource:(NSInteger)sourceID position:(simd_float3)position {
    dispatch_async(_audioQueue, ^{
        AudioSource *source = self.audioSources[@(sourceID)];
        if (!source) {
            source = [[AudioSource alloc] init];
            source.sourceID = sourceID;
            source.frequency = 440.0;
            source.gain = 1.0;
            source.isActive = YES;
            self.audioSources[@(sourceID)] = source;
        }
        source.position = position;
    });
}

- (void)setAudioSource:(NSInteger)sourceID frequency:(float)frequency {
    dispatch_async(_audioQueue, ^{
        AudioSource *source = self.audioSources[@(sourceID)];
        if (source) {
            source.frequency = frequency;
        }
    });
}

- (void)setAudioSource:(NSInteger)sourceID gain:(float)gain {
    dispatch_async(_audioQueue, ^{
        AudioSource *source = self.audioSources[@(sourceID)];
        if (source) {
            source.gain = gain;
        }
    });
}

- (void)removeAudioSource:(NSInteger)sourceID {
    dispatch_async(_audioQueue, ^{
        [self.audioSources removeObjectForKey:@(sourceID)];
    });
}

- (void)processAudioBuffer:(float *)buffer frameCount:(NSUInteger)frameCount {
    if (!_isRunning) {
        memset(buffer, 0, frameCount * sizeof(float));
        return;
    }

    // Clear buffer
    memset(buffer, 0, frameCount * sizeof(float));

    // Process each source
    for (AudioSource *source in _audioSources.allValues) {
        if (!source.isActive) continue;

        // Calculate distance and direction
        simd_float3 direction = source.position - _listenerPosition;
        float distance = simd_length(direction);

        // Inverse square law with absorption
        float attenuation = 1.0 / (1.0 + distance * distance * 0.1);
        float gain = source.gain * attenuation * _globalGain;

        // Get acoustic field energy at listener position
        float acousticEnergy = [_acousticSimulator getEnergyAtPosition:_listenerPosition];
        gain *= (0.5 + 0.5 * acousticEnergy);

        // Generate sine wave
        float phaseIncrement = 2.0 * M_PI * source.frequency / _sampleRate;

        for (NSUInteger i = 0; i < frameCount; i++) {
            float sample = sin(source.phase) * gain;
            buffer[i] += sample;
            source.phase += phaseIncrement;
            if (source.phase > 2.0 * M_PI) {
                source.phase -= 2.0 * M_PI;
            }
        }
    }

    // Soft clipping
    for (NSUInteger i = 0; i < frameCount; i++) {
        float sample = buffer[i];
        buffer[i] = sample / (1.0 + fabs(sample));
    }

    _currentTime += frameCount / _sampleRate;
}

- (void)processStereoBuffer:(float *)leftBuffer right:(float *)rightBuffer frameCount:(NSUInteger)frameCount {
    if (!_isRunning) {
        memset(leftBuffer, 0, frameCount * sizeof(float));
        memset(rightBuffer, 0, frameCount * sizeof(float));
        return;
    }

    // Clear buffers
    memset(leftBuffer, 0, frameCount * sizeof(float));
    memset(rightBuffer, 0, frameCount * sizeof(float));

    // Process each source with binaural panning
    for (AudioSource *source in _audioSources.allValues) {
        if (!source.isActive) continue;

        simd_float3 direction = source.position - _listenerPosition;
        float distance = simd_length(direction);

        // Normalize direction
        simd_float3 normDir = direction / distance;

        // Calculate pan based on angle to listener orientation
        float pan = normDir.x; // Simplified panning
        float leftGain = (1.0 - pan) * 0.5;
        float rightGain = (1.0 + pan) * 0.5;

        // Attenuation
        float attenuation = 1.0 / (1.0 + distance * distance * 0.1);
        float baseGain = source.gain * attenuation * _globalGain;

        // Acoustic field
        float acousticEnergy = [_acousticSimulator getEnergyAtPosition:_listenerPosition];
        baseGain *= (0.5 + 0.5 * acousticEnergy);

        // Generate audio
        float phaseIncrement = 2.0 * M_PI * source.frequency / _sampleRate;

        for (NSUInteger i = 0; i < frameCount; i++) {
            float sample = sin(source.phase) * baseGain;
            leftBuffer[i] += sample * leftGain;
            rightBuffer[i] += sample * rightGain;

            source.phase += phaseIncrement;
            if (source.phase > 2.0 * M_PI) {
                source.phase -= 2.0 * M_PI;
            }
        }
    }

    // Soft clipping
    for (NSUInteger i = 0; i < frameCount; i++) {
        leftBuffer[i] = leftBuffer[i] / (1.0 + fabs(leftBuffer[i]));
        rightBuffer[i] = rightBuffer[i] / (1.0 + fabs(rightBuffer[i]));
    }

    _currentTime += frameCount / _sampleRate;
}

- (void)setSceneGeometry:(id<MTLTexture>)geometryTexture {
    [_acousticSimulator setSceneGeometry:geometryTexture];
}

- (void)updateRayTracing {
    // Update ray tracing simulation
    [_acousticSimulator simulateReflections];
}

@end
