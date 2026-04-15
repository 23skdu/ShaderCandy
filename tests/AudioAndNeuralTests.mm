#import "../src/audio/AudioInput.h"
#import "../src/neural/NeuralStyleEngine.h"
#import "../src/audio/AcousticSimulator.h"
#import "../src/audio/RayAudioEngine.h"
#import "../src/audio/SoundscapeGenerator.h"
#import "../src/audio/SpatialSoundscapeGenerator.h"
#include "TestFramework.h"
#include <vector>
#include <iostream>

namespace ShaderCandy {
namespace Test {

class AudioAndNeuralTests : public TestSuite {
public:
    std::string getName() const override { return "Audio and Neural Tests"; }

    std::vector<TestResult> run() override {
        std::vector<TestResult> results;
        results.push_back(testAudioInputAnalysis());
        results.push_back(testNeuralEngineBasics());
        results.push_back(testSoundscapeBasics());
        return results;
    }

private:
    TestResult testAudioInputAnalysis() {
        Audio::AudioInput audio;
        
        // Mock data: Sine wave
        std::vector<float> samples(1024);
        for(int i=0; i<1024; i++) {
            samples[i] = sinf(i * 0.1f);
        }
        
        // Call analysis directly
        audio.performFFT(samples);
        
        auto data = audio.getCurrentData();
        TEST_ASSERT(data.volume > 0, "Volume should be non-zero");
        TEST_ASSERT(!data.spectrum.empty(), "Spectrum should be calculated");
        TEST_ASSERT(data.bass >= 0, "Bass should be calculated");
        
        // Utils
        float freq = Audio::Utils::getDominantFrequency(data);
        TEST_ASSERT(freq >= 0, "Dominant frequency failed");
        
        float centroid = Audio::Utils::getSpectralCentroid(data);
        TEST_ASSERT(centroid >= 0, "Spectral centroid failed");
        
        float packed[128];
        Audio::Utils::packAudioForShader(data, packed, 128);
        
        return {__func__, true, "Audio analysis passed", 0.0};
    }

    TestResult testNeuralEngineBasics() {
        NeuralStyleEngine *engine = [NeuralStyleEngine sharedEngine];
        [engine availableStyles];
        engine.styleStrength = 0.5f;
        TEST_ASSERT(engine.styleStrength == 0.5f, "Style strength failed");
        
        NSError *error = nil;
        [engine loadStyleNamed:@"non-existent" error:&error];
        TEST_ASSERT(error != nil, "Should fail loading non-existent style");
        
        [engine shutdown];
        return {__func__, true, "Neural engine basics passed", 0.0};
    }

    TestResult testSoundscapeBasics() {
        // Just instantiate the audio objects to ensure they can be created
        AcousticSimulator *sim = [[AcousticSimulator alloc] init];
        TEST_ASSERT(sim != nil, "AcousticSimulator instantiation failed");
        
        RayAudioEngine *ray = [[RayAudioEngine alloc] init];
        TEST_ASSERT(ray != nil, "RayAudioEngine instantiation failed");
        
        SoundscapeGenerator *gen = [SoundscapeGenerator sharedGenerator];
        TEST_ASSERT(gen != nil, "SoundscapeGenerator instantiation failed");
        
        SpatialSoundscapeGenerator *spatial = [SpatialSoundscapeGenerator sharedGenerator];
        TEST_ASSERT(spatial != nil, "SpatialSoundscapeGenerator instantiation failed");
        
        return {__func__, true, "Soundscape basics passed", 0.0};
    }
};

REGISTER_TEST_SUITE(AudioAndNeuralTests);

} // namespace Test
} // namespace ShaderCandy
