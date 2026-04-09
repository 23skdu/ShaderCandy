#pragma once

#include <atomic>
#include <complex>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

namespace ShaderCandy {
namespace Audio {

// Audio analysis data structure
struct AudioData {
  // Time domain
  std::vector<float> waveform; // Raw audio samples
  float volume;                // Current volume (0-1)
  float volumeSmoothed;        // Smoothed volume

  // Frequency domain (FFT)
  std::vector<float> spectrum;       // FFT magnitude data
  std::vector<float> spectrumSmooth; // Smoothed spectrum

  // Beat detection
  float bass;          // Low frequency energy
  float mid;           // Mid frequency energy
  float treble;        // High frequency energy
  bool beat;           // Beat detected this frame
  float beatIntensity; // How strong the beat is

  // Frequency bands (equalizer-style)
  static constexpr int NUM_BANDS = 8;
  float bands[NUM_BANDS]; // 8 frequency bands

  AudioData()
      : volume(0), volumeSmoothed(0), bass(0), mid(0), treble(0), beat(false),
        beatIntensity(0) {
    std::fill(bands, bands + NUM_BANDS, 0.0f);
  }
};

// Callback type for audio data
using AudioCallback = std::function<void(const AudioData &)>;

class AudioInput {
public:
  AudioInput();
  ~AudioInput();

  // Prevent copying
  AudioInput(const AudioInput &) = delete;
  AudioInput &operator=(const AudioInput &) = delete;

  // Control
  bool initialize(int sampleRate = 44100, int bufferSize = 1024);
  bool start();
  void stop();
  bool isRunning() const;

  // Configuration
  void setCallback(AudioCallback callback);
  void setSmoothing(float amount); // 0-1, higher = smoother
  void setBeatThreshold(float threshold);

  // Get current data (thread-safe)
  AudioData getCurrentData() const;

  // Device enumeration
  static std::vector<std::string> getAvailableDevices();
  bool selectDevice(const std::string &deviceName);

  // Auto-detect input source
  bool autoSelectDevice();
  bool openDevice(const std::string &deviceName);

  // Internal processing (public for delegate access)
  void performFFT(const std::vector<float> &samples);

  void onAudioData(const AudioData &audioData);

private:
  class Impl;
  std::unique_ptr<Impl> impl_;

  // Configuration
  int sampleRate_;
  int bufferSize_;
  float smoothing_;
  float beatThreshold_;

  // Threading
  mutable std::mutex dataMutex_;
  std::atomic<bool> running_;

  // Audio data
  AudioData currentData_;
  AudioCallback callback_;

  // FFT processing
  std::vector<std::complex<float>> fftBuffer_;
  std::vector<float> fftWindow_;
  void analyzeFrequencyBands();
  void detectBeat();
};

// Utility functions for shaders
namespace Utils {
// Convert audio data to uniform-friendly format
void packAudioForShader(const AudioData &audio, float *output, int maxSamples);

// Get dominant frequency
float getDominantFrequency(const AudioData &audio);

// Calculate spectral centroid (brightness)
float getSpectralCentroid(const AudioData &audio);

// Check if frequency band has energy
bool bandHasEnergy(const AudioData &audio, int band, float threshold = 0.3f);
} // namespace Utils

} // namespace Audio
} // namespace ShaderCandy
