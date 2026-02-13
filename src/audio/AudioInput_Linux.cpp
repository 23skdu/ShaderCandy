// Linux Audio Input Implementation for ShaderCandy
// Uses ALSA for audio capture and FFTW3 for FFT processing

#include "AudioInput.h"

#include <alsa/asoundlib.h>
#include <fftw3.h>
#include <cmath>
#include <cstring>
#include <iostream>
#include <thread>

namespace ShaderCandy {
namespace Audio {

class AudioInput::Impl {
public:
  Impl(AudioInput *parent) : parent_(parent), pcmHandle_(nullptr), fftPlan_(nullptr) {}

  ~Impl() { cleanup(); }

  bool initialize(int sampleRate, int bufferSize) {
    sampleRate_ = sampleRate;
    bufferSize_ = bufferSize;

    // Allocate buffers
    inputBuffer_.resize(bufferSize);
    fftIn_ = (double *)fftw_malloc(sizeof(double) * bufferSize);
    fftOut_ = (fftw_complex *)fftw_malloc(sizeof(fftw_complex) * (bufferSize / 2 + 1));
    fftWindow_.resize(bufferSize);

    // Create Hann window
    for (int i = 0; i < bufferSize; ++i) {
      fftWindow_[i] = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (bufferSize - 1)));
    }

    // Create FFT plan
    fftPlan_ = fftw_plan_dft_r2c_1d(bufferSize, fftIn_, fftOut_, FFTW_ESTIMATE);
    if (!fftPlan_) {
      std::cerr << "Failed to create FFT plan" << std::endl;
      return false;
    }

    return true;
  }

  bool openDevice(const std::string &deviceName) {
    // Default to "default" device if not specified
    const char *device = deviceName.empty() ? "default" : deviceName.c_str();

    int err = snd_pcm_open(&pcmHandle_, device, SND_PCM_STREAM_CAPTURE, 0);
    if (err < 0) {
      std::cerr << "Cannot open audio device " << device << ": " << snd_strerror(err) << std::endl;
      return false;
    }

    // Configure hardware parameters
    snd_pcm_hw_params_t *hwParams;
    snd_pcm_hw_params_alloca(&hwParams);
    snd_pcm_hw_params_any(pcmHandle_, hwParams);
    snd_pcm_hw_params_set_access(pcmHandle_, hwParams, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(pcmHandle_, hwParams, SND_PCM_FORMAT_FLOAT_LE);
    snd_pcm_hw_params_set_channels(pcmHandle_, hwParams, 1); // Mono
    unsigned int rate = sampleRate_;
    int dir = 0;
    snd_pcm_hw_params_set_rate_near(pcmHandle_, hwParams, &rate, &dir);
    snd_pcm_uframes_t periodSize = bufferSize_;
    snd_pcm_hw_params_set_period_size_near(pcmHandle_, hwParams, &periodSize, &dir);

    err = snd_pcm_hw_params(pcmHandle_, hwParams);
    if (err < 0) {
      std::cerr << "Cannot set hardware parameters: " << snd_strerror(err) << std::endl;
      snd_pcm_close(pcmHandle_);
      pcmHandle_ = nullptr;
      return false;
    }

    // Prepare PCM
    err = snd_pcm_prepare(pcmHandle_);
    if (err < 0) {
      std::cerr << "Cannot prepare audio interface: " << snd_strerror(err) << std::endl;
      snd_pcm_close(pcmHandle_);
      pcmHandle_ = nullptr;
      return false;
    }

    deviceName_ = device;
    return true;
  }

  void start() {
    if (running_.load()) return;

    running_ = true;
    captureThread_ = std::thread(&Impl::captureLoop, this);
  }

  void stop() {
    running_ = false;
    if (captureThread_.joinable()) {
      captureThread_.join();
    }

    if (pcmHandle_) {
      snd_pcm_drop(pcmHandle_);
    }
  }

  void captureLoop() {
    std::vector<float> samples(bufferSize_);

    while (running_.load()) {
      if (!pcmHandle_) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        continue;
      }

      // Read audio data
      int err = snd_pcm_readi(pcmHandle_, samples.data(), bufferSize_);
      if (err == -EPIPE) {
        // Overrun
        snd_pcm_prepare(pcmHandle_);
        continue;
      } else if (err < 0) {
        std::cerr << "Read error: " << snd_strerror(err) << std::endl;
        continue;
      } else if (err != bufferSize_) {
        // Short read
        continue;
      }

      // Process the audio
      parent_->performFFT(samples);
    }
  }

  void performFFT(const std::vector<float> &samples, AudioData &data) {
    // Apply window and convert to double
    for (int i = 0; i < bufferSize_; ++i) {
      fftIn_[i] = samples[i] * fftWindow_[i];
    }

    // Execute FFT
    fftw_execute(fftPlan_);

    // Calculate magnitude spectrum
    data.spectrum.resize(bufferSize_ / 2);
    for (int i = 0; i < bufferSize_ / 2; ++i) {
      double real = fftOut_[i][0];
      double imag = fftOut_[i][1];
      data.spectrum[i] = std::sqrt(real * real + imag * imag) / bufferSize_;
    }

    // Calculate volume
    float sum = 0.0f;
    for (float sample : samples) {
      sum += sample * sample;
    }
    data.volume = std::sqrt(sum / samples.size());
  }

  std::vector<std::string> getAvailableDevices() {
    std::vector<std::string> devices;
    
    void **hints, **n;
    char *name, *descr, *io;
    
    if (snd_device_name_hint(-1, "pcm", &hints) >= 0) {
      for (n = hints; *n != nullptr; n++) {
        name = snd_device_name_get_hint(*n, "NAME");
        descr = snd_device_name_get_hint(*n, "DESC");
        io = snd_device_name_get_hint(*n, "IOID");
        
        if (name != nullptr && (io == nullptr || strcmp(io, "Input") == 0)) {
          devices.emplace_back(name);
        }
        
        free(name);
        free(descr);
        free(io);
      }
      snd_device_name_free_hint(hints);
    }
    
    return devices;
  }

private:
  void cleanup() {
    stop();

    if (pcmHandle_) {
      snd_pcm_close(pcmHandle_);
      pcmHandle_ = nullptr;
    }

    if (fftPlan_) {
      fftw_destroy_plan(fftPlan_);
      fftPlan_ = nullptr;
    }

    if (fftIn_) {
      fftw_free(fftIn_);
      fftIn_ = nullptr;
    }

    if (fftOut_) {
      fftw_free(fftOut_);
      fftOut_ = nullptr;
    }
  }

  AudioInput *parent_;
  snd_pcm_t *pcmHandle_;
  std::thread captureThread_;
  std::atomic<bool> running_{false};

  int sampleRate_;
  int bufferSize_;
  std::string deviceName_;

  // FFTW
  fftw_plan fftPlan_;
  double *fftIn_ = nullptr;
  fftw_complex *fftOut_ = nullptr;
  std::vector<float> fftWindow_;
  std::vector<float> inputBuffer_;
};

// AudioInput method implementations

AudioInput::AudioInput()
    : pImpl(std::make_unique<Impl>(this)),
      sampleRate_(44100),
      bufferSize_(1024),
      smoothing_(0.8f),
      beatThreshold_(0.1f) {
  running_ = false;
}

AudioInput::~AudioInput() {
  stop();
}

bool AudioInput::initialize(int sampleRate, int bufferSize) {
  sampleRate_ = sampleRate;
  bufferSize_ = bufferSize;
  
  if (!pImpl->initialize(sampleRate, bufferSize)) {
    return false;
  }

  return true;
}

void AudioInput::start() {
  if (running_.load()) return;

  // Open default device if not already open
  if (!pImpl->openDevice("")) {
    std::cerr << "Failed to open audio device" << std::endl;
    return;
  }

  pImpl->start();
  running_ = true;
}

void AudioInput::stop() {
  pImpl->stop();
  running_ = false;
}

bool AudioInput::isRunning() const {
  return running_.load();
}

void AudioInput::setCallback(AudioCallback callback) {
  std::lock_guard<std::mutex> lock(dataMutex_);
  callback_ = callback;
}

void AudioInput::setSmoothing(float amount) {
  smoothing_ = std::clamp(amount, 0.0f, 1.0f);
}

void AudioInput::setBeatThreshold(float threshold) {
  beatThreshold_ = std::clamp(threshold, 0.0f, 1.0f);
}

AudioData AudioInput::getCurrentData() const {
  std::lock_guard<std::mutex> lock(dataMutex_);
  return currentData_;
}

std::vector<std::string> AudioInput::getAvailableDevices() {
  return Impl(nullptr).getAvailableDevices();
}

bool AudioInput::selectDevice(const std::string &deviceName) {
  return pImpl->openDevice(deviceName);
}

bool AudioInput::autoSelectDevice() {
  // Try default first
  if (pImpl->openDevice("default")) {
    return true;
  }
  
  // Try hw:0,0
  if (pImpl->openDevice("hw:0,0")) {
    return true;
  }

  // Try to find any available device
  auto devices = getAvailableDevices();
  for (const auto &device : devices) {
    if (pImpl->openDevice(device)) {
      return true;
    }
  }

  return false;
}

void AudioInput::performFFT(const std::vector<float> &samples) {
  AudioData newData;

  // Perform FFT
  pImpl->performFFT(samples, newData);

  // Update waveform
  newData.waveform = samples;

  // Apply smoothing
  {
    std::lock_guard<std::mutex> lock(dataMutex_);

    // Smooth volume
    newData.volumeSmoothed = smoothing_ * currentData_.volumeSmoothed +
                             (1.0f - smoothing_) * newData.volume;

    // Smooth spectrum
    newData.spectrumSmooth = newData.spectrum;
    if (!currentData_.spectrumSmooth.empty()) {
      for (size_t i = 0; i < newData.spectrumSmooth.size(); ++i) {
        if (i < currentData_.spectrumSmooth.size()) {
          newData.spectrumSmooth[i] = smoothing_ * currentData_.spectrumSmooth[i] +
                                      (1.0f - smoothing_) * newData.spectrum[i];
        }
      }
    }

    // Analyze frequency bands
    analyzeFrequencyBands(newData);

    // Detect beat
    detectBeat(newData);

    currentData_ = newData;

    // Call callback if set
    if (callback_) {
      callback_(currentData_);
    }
  }
}

void AudioInput::analyzeFrequencyBands(AudioData &data) {
  if (data.spectrum.empty()) return;

  int spectrumSize = data.spectrum.size();
  float binSize = sampleRate_ / 2.0f / spectrumSize;

  // Define frequency ranges for bands
  // Band 0: 0-60Hz (Sub bass)
  // Band 1: 60-120Hz (Bass)
  // Band 2: 120-250Hz (Low mid)
  // Band 3: 250-500Hz (Mid)
  // Band 4: 500-1000Hz (High mid)
  // Band 5: 1-2kHz (Presence)
  // Band 6: 2-6kHz (Brilliance)
  // Band 7: 6-20kHz (Air)
  float bandLimits[] = {60, 120, 250, 500, 1000, 2000, 6000, 20000};

  int startBin = 0;
  for (int band = 0; band < AudioData::NUM_BANDS; ++band) {
    int endFreq = bandLimits[band];
    int endBin = std::min(spectrumSize, (int)(endFreq / binSize));

    float sum = 0.0f;
    int count = 0;
    for (int i = startBin; i < endBin && i < spectrumSize; ++i) {
      sum += data.spectrum[i];
      count++;
    }

    data.bands[band] = count > 0 ? sum / count : 0.0f;
    startBin = endBin;
  }

  // Set bass, mid, treble from bands
  data.bass = (data.bands[0] + data.bands[1]) / 2.0f;
  data.mid = (data.bands[2] + data.bands[3] + data.bands[4]) / 3.0f;
  data.treble = (data.bands[5] + data.bands[6] + data.bands[7]) / 3.0f;
}

void AudioInput::detectBeat(AudioData &data) {
  static float lastBass = 0.0f;
  static float bassHistory = 0.0f;

  // Simple beat detection based on bass energy spike
  bassHistory = bassHistory * 0.9f + data.bass * 0.1f;

  if (data.bass > bassHistory * (1.0f + beatThreshold_) && data.bass > 0.1f) {
    data.beat = true;
    data.beatIntensity = std::min(1.0f, data.bass / bassHistory - 1.0f);
  } else {
    data.beat = false;
    data.beatIntensity = 0.0f;
  }

  lastBass = data.bass;
}

namespace Utils {

void packAudioForShader(const AudioData &audio, float *output, int maxSamples) {
  if (!output || maxSamples <= 0) return;

  // Pack audio data into uniform-friendly format
  // First 8 values: frequency bands
  for (int i = 0; i < AudioData::NUM_BANDS && i < maxSamples; ++i) {
    output[i] = audio.bands[i];
  }

  // Next 4 values: volume, bass, mid, treble
  if (maxSamples > 8) output[8] = audio.volume;
  if (maxSamples > 9) output[9] = audio.bass;
  if (maxSamples > 10) output[10] = audio.mid;
  if (maxSamples > 11) output[11] = audio.treble;

  // Remaining: spectrum samples (downsampled if needed)
  int spectrumStart = 12;
  int spectrumSamples = std::min((int)audio.spectrum.size(), maxSamples - spectrumStart);
  for (int i = 0; i < spectrumSamples; ++i) {
    output[spectrumStart + i] = audio.spectrum[i];
  }
}

float getDominantFrequency(const AudioData &audio) {
  if (audio.spectrum.empty()) return 0.0f;

  // Find peak in spectrum
  float maxVal = 0.0f;
  int maxIdx = 0;
  for (size_t i = 0; i < audio.spectrum.size(); ++i) {
    if (audio.spectrum[i] > maxVal) {
      maxVal = audio.spectrum[i];
      maxIdx = i;
    }
  }

  // Convert bin index to frequency
  return maxIdx * (44100.0f / 2.0f) / audio.spectrum.size();
}

float getSpectralCentroid(const AudioData &audio) {
  if (audio.spectrum.empty()) return 0.0f;

  float sum = 0.0f;
  float weightedSum = 0.0f;

  for (size_t i = 0; i < audio.spectrum.size(); ++i) {
    float freq = i * (44100.0f / 2.0f) / audio.spectrum.size();
    sum += audio.spectrum[i];
    weightedSum += freq * audio.spectrum[i];
  }

  return sum > 0.0f ? weightedSum / sum : 0.0f;
}

bool bandHasEnergy(const AudioData &audio, int band, float threshold) {
  if (band < 0 || band >= AudioData::NUM_BANDS) return false;
  return audio.bands[band] > threshold;
}

} // namespace Utils

} // namespace Audio
} // namespace ShaderCandy
