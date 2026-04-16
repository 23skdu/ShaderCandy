#import "SoundscapeGenerator.h"
#import "../config/ConfigurationManager.h"
#import "RayAudioEngine.h"
#import "SpatialSoundscapeGenerator.h"
#import <AVFoundation/AVFoundation.h>

@interface SoundscapeGenerator ()
@end

@implementation SoundscapeGenerator {
  AVAudioEngine *_engine;
  AVAudioSourceNode *_sourceNode;
  AVAudioUnitReverb *_reverb;
  AVAudioUnitEQ *_eq;

  // Synthesis state
  double _phase1;
  double _phase2;
  double _phase3;
  float _currentIntensity;
  float _currentSpeed;
  float _currentComplexity;

  // Modulation targets
  float _targetFrequency1;
  float _targetFrequency2;
  float _targetFrequency3;
  float _volume1;
  float _volume2;
}

+ (instancetype)sharedGenerator {
  static SoundscapeGenerator *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[SoundscapeGenerator alloc] init];
  });
  return shared;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _enabled = NO; // Disabled by default until started
    _masterVolume = 0.5f;
    _activeType = SoundscapeTypeCosmicDrone;

    _phase1 = 0;
    _phase2 = 0;
    _phase3 = 0;
    _currentIntensity = 1.0f;
    _currentSpeed = 1.0f;

    _targetFrequency1 = 55.0f;  // A1
    _targetFrequency2 = 55.44f; // Slightly detuned
    _targetFrequency3 = 110.0f; // A2
  }
  return self;
}

- (void)setupEngine {
  if (_engine) return;
  _engine = [[AVAudioEngine alloc] init];

  // Create synthesis node
  _sourceNode = [[AVAudioSourceNode alloc]
      initWithRenderBlock:^OSStatus(
          BOOL *_Nonnull silence, const AudioTimeStamp *_Nonnull timestamp,
          AVAudioFrameCount frameCount, AudioBufferList *_Nonnull outputData) {
        float *left = (float *)outputData->mBuffers[0].mData;
        float *right = (float *)outputData->mBuffers[1].mData;

        double sampleRate =
            44100.0; // Standard for AVAudioSourceNode if not specified

        for (AVAudioFrameCount frame = 0; frame < frameCount; frame++) {
          if (!self->_enabled || self->_activeType == SoundscapeTypeNone) {
            left[frame] = 0;
            right[frame] = 0;
            continue;
          }

          // Oscillator 1 (Base Drone)
          float val1 = sin(self->_phase1);
          self->_phase1 += 2.0 * M_PI * self->_targetFrequency1 / sampleRate;
          if (self->_phase1 > 2.0 * M_PI)
            self->_phase1 -= 2.0 * M_PI;

          // Oscillator 2 (Beating Texture)
          float val2 = sin(self->_phase2);
          self->_phase2 += 2.0 * M_PI * self->_targetFrequency2 / sampleRate;
          if (self->_phase2 > 2.0 * M_PI)
            self->_phase2 -= 2.0 * M_PI;

          // Oscillator 3 (Sub Harmony)
          float val3 = sin(self->_phase3);
          self->_phase3 += 2.0 * M_PI * self->_targetFrequency3 / sampleRate;
          if (self->_phase3 > 2.0 * M_PI)
            self->_phase3 -= 2.0 * M_PI;

          // Mix
          float mixed =
              (val1 * 0.4f + val2 * 0.4f + val3 * 0.2f) * self->_masterVolume;

          // Subtle noise floor for "Atmospheric" feel
          float noise = ((float)arc4random() / (float)UINT32_MAX) * 0.01f;
          mixed += noise * self->_currentComplexity;

          left[frame] = mixed;
          right[frame] = mixed;
        }

        return noErr;
      }];

  _reverb = [[AVAudioUnitReverb alloc] init];
  [_reverb loadFactoryPreset:AVAudioUnitReverbPresetCathedral];
  _reverb.wetDryMix = 40.0f;

  _eq = [[AVAudioUnitEQ alloc] initWithNumberOfBands:1];
  _eq.bands[0].filterType = AVAudioUnitEQFilterTypeLowPass;
  _eq.bands[0].frequency = 2000.0f;
  _eq.bands[0].bypass = NO;

  [_engine attachNode:_sourceNode];
  [_engine attachNode:_reverb];
  [_engine attachNode:_eq];

  AVAudioFormat *format = [[_engine mainMixerNode] outputFormatForBus:0];

  [_engine connect:_sourceNode to:_eq format:format];
  [_engine connect:_eq to:_reverb format:format];
  [_engine connect:_reverb to:[_engine mainMixerNode] format:format];

  // Initialize Spatial Audio Engine as secondary
  [[RayAudioEngine sharedEngine] initializeWithSampleRate:format.sampleRate
                                                    error:nil];
  [[SpatialSoundscapeGenerator sharedGenerator]
      initializeWithSampleRate:format.sampleRate
                         error:nil];
}

- (BOOL)start {
  [self setupEngine];
  NSError *error = nil;
  if (![_engine startAndReturnError:&error]) {
    NSLog(@"SoundscapeGenerator: Failed to start engine: %@", error);
    return NO;
  }
  return YES;
}

- (void)stop {
  [_engine stop];
}

- (void)updateWithMetrics:(SoundscapeMetrics)metrics {
  _currentIntensity = metrics.intensity;
  _currentSpeed = metrics.speed;
  _currentComplexity = metrics.visualComplexity;

  // Modulate Low Pass based on Intensity
  // Map 0-1 intensity to 200Hz - 8000Hz
  float cutoff = 200.0f + (metrics.intensity * 7800.0f);
  _eq.bands[0].frequency = cutoff;

  // Modulate Detuning based on Speed (higher speed = more chaotic beating)
  _targetFrequency2 = _targetFrequency1 + (0.44f * metrics.speed);

  // Modulate Reverb based on complexity
  _reverb.wetDryMix = 20.0f + (metrics.visualComplexity * 60.0f);

  // Phase 5: Ray-Traced Audio Sync
  if ([SpatialSoundscapeGenerator sharedGenerator]) {
    [SpatialSoundscapeGenerator sharedGenerator].visualComplexity =
        metrics.visualComplexity;

    // Auto-update room parameters from global config
    auto &config = ShaderCandy::Config::ConfigurationManager::getInstance();
    const auto &settings = config.getSettings();
    if (settings.spatialAudio) {
      [[SpatialSoundscapeGenerator sharedGenerator]
          setReverbParameters:settings.roomSize
                      damping:settings.reverbDamping
                    intensity:metrics.intensity];
      [[RayAudioEngine sharedEngine] start];
    } else {
      [[RayAudioEngine sharedEngine] stop];
    }
  }
}

- (void)transitionToSoundscape:(SoundscapeType)type
                      duration:(NSTimeInterval)duration {
  // Basic implementation: set immediately for now
  _activeType = type;

  if (type == SoundscapeTypeCosmicDrone) {
    _targetFrequency1 = 55.0f;
    _targetFrequency2 = 55.44f;
    _reverb.wetDryMix = 40.0f;
  } else if (type == SoundscapeTypeDigitalWind) {
    _targetFrequency1 = 110.0f;
    _targetFrequency2 = 112.0f;
    _reverb.wetDryMix = 70.0f;
  }
}

@end
