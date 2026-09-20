#pragma once

#ifndef HAS_AUDIO

#include <algorithm>
#include <vector>

namespace ShaderCandy {
namespace Audio {

// Audio analysis data structure
// Stub version for builds without full audio support.
// Matches the interface in AudioInput.h.
struct AudioData {
  std::vector<float> waveform;
  float volume = 0.0f;
  float volumeSmoothed = 0.0f;

  std::vector<float> spectrum;
  std::vector<float> spectrumSmooth;

  float bass = 0.0f;
  float mid = 0.0f;
  float treble = 0.0f;
  bool beat = false;
  float beatIntensity = 0.0f;

  static constexpr int NUM_BANDS = 8;
  float bands[NUM_BANDS] = {};

  AudioData() { std::fill(bands, bands + NUM_BANDS, 0.0f); }
};

} // namespace Audio
} // namespace ShaderCandy

#endif // HAS_AUDIO
