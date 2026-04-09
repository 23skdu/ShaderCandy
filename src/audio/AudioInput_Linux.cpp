// Linux Audio Input Implementation for ShaderCandy
// Supports: PipeWire (via PulseAudio) > PulseAudio > ALSA

#include "AudioInput.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <fftw3.h>
#include <iostream>
#include <thread>
#include <alsa/asoundlib.h>

namespace ShaderCandy {
namespace Audio {

class AudioInput::Impl {
public:
  Impl(AudioInput *parent)
      : parent_(parent), pcmHandle_(nullptr), fftPlan_(nullptr) {}

  ~Impl() { cleanup(); }

  bool initialize(int sampleRate, int bufferSize) {
    sampleRate_ = sampleRate;
    bufferSize_ = bufferSize;

    inputBuffer_.resize(bufferSize);
    fftIn_ = (double *)fftw_malloc(sizeof(double) * bufferSize);
    fftOut_ = (fftw_complex *)fftw_malloc(sizeof(fftw_complex) *
                                          (bufferSize / 2 + 1));
    fftWindow_.resize(bufferSize);

    for (int i = 0; i < bufferSize; ++i) {
      fftWindow_[i] =
          0.5f * (1.0f - std::cos(2.0f * M_PI * i / (bufferSize - 1)));
    }

    fftPlan_ = fftw_plan_dft_r2c_1d(bufferSize, fftIn_, fftOut_, FFTW_ESTIMATE);
    if (!fftPlan_) {
      std::cerr << "Failed to create FFT plan" << std::endl;
      return false;
    }

    return true;
  }

  bool openDevice(const std::string &deviceName) {
    const char *device = deviceName.empty() ? "default" : deviceName.c_str();

    int err = snd_pcm_open(&pcmHandle_, device, SND_PCM_STREAM_CAPTURE, 0);
    if (err < 0) {
      std::cerr << "Cannot open audio device " << device << ": "
                << snd_strerror(err) << std::endl;
      return false;
    }

    snd_pcm_hw_params_t *hwParams;
    snd_pcm_hw_params_alloca(&hwParams);
    snd_pcm_hw_params_any(pcmHandle_, hwParams);
    snd_pcm_hw_params_set_access(pcmHandle_, hwParams,
                                 SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(pcmHandle_, hwParams, SND_PCM_FORMAT_FLOAT_LE);
    snd_pcm_hw_params_set_channels(pcmHandle_, hwParams, 1);
    unsigned int rate = sampleRate_;
    int dir = 0;
    snd_pcm_hw_params_set_rate_near(pcmHandle_, hwParams, &rate, &dir);
    snd_pcm_uframes_t periodSize = bufferSize_;
    snd_pcm_hw_params_set_period_size_near(pcmHandle_, hwParams, &periodSize,
                                           &dir);

    err = snd_pcm_hw_params(pcmHandle_, hwParams);
    if (err < 0) {
      std::cerr << "Cannot set hardware parameters: " << snd_strerror(err)
                << std::endl;
      snd_pcm_close(pcmHandle_);
      pcmHandle_ = nullptr;
      return false;
    }

    err = snd_pcm_prepare(pcmHandle_);
    if (err < 0) {
      std::cerr << "Cannot prepare audio interface: " << snd_strerror(err)
                << std::endl;
      snd_pcm_close(pcmHandle_);
      pcmHandle_ = nullptr;
      return false;
    }

    deviceName_ = device;
    return true;
  }

  void start() {
    if (running_.load())
      return;
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

      int frames = snd_pcm_readi(pcmHandle_, samples.data(), bufferSize_);
      if (frames < 0) {
        frames = snd_pcm_recover(pcmHandle_, frames, 1);
        if (frames < 0) {
          std::cerr << "Read error: " << snd_strerror(frames) << std::endl;
          std::this_thread::sleep_for(std::chrono::milliseconds(10));
          continue;
        }
      }

      for (int i = 0; i < frames && i < bufferSize_; ++i) {
        inputBuffer_[i] = samples[i];
      }

      processAudio();
      parent_->onAudioData(audioData_);
    }
  }

  void processAudio() {
    if (!fftPlan_)
      return;

    for (size_t i = 0; i < inputBuffer_.size(); ++i) {
      fftIn_[i] = inputBuffer_[i] * fftWindow_[i];
    }
    fftw_execute(fftPlan_);

    double volume = 0.0;
    for (size_t i = 0; i < inputBuffer_.size(); ++i) {
      volume += std::abs(inputBuffer_[i]);
    }
    audioData_.volume = volume / inputBuffer_.size();

    int halfSize = bufferSize_ / 2;
    double bass = 0.0, mid = 0.0, treble = 0.0;
    int bassEnd = halfSize / 4;
    int midEnd = halfSize / 2;

    for (int i = 0; i < bassEnd; ++i) {
      double mag = std::sqrt(fftOut_[i][0] * fftOut_[i][0] +
                         fftOut_[i][1] * fftOut_[i][1]) / halfSize;
      bass += mag;
    }
    audioData_.bass = bass / bassEnd;

    for (int i = bassEnd; i < midEnd; ++i) {
      double mag = std::sqrt(fftOut_[i][0] * fftOut_[i][0] +
                         fftOut_[i][1] * fftOut_[i][1]) / halfSize;
      mid += mag;
    }
    audioData_.mid = mid / (midEnd - bassEnd);

    for (int i = midEnd; i < halfSize; ++i) {
      double mag = std::sqrt(fftOut_[i][0] * fftOut_[i][0] +
                         fftOut_[i][1] * fftOut_[i][1]) / halfSize;
      treble += mag;
    }
    audioData_.treble = treble / (halfSize - midEnd);

    audioData_.beat = (audioData_.bass > 0.5f) ? 1.0f : 0.0f;

    for (int i = 0; i < 8; ++i) {
      int start = i * halfSize / 8;
      int end = (i + 1) * halfSize / 8;
      double band = 0.0;
      for (int j = start; j < end; ++j) {
        double mag = std::sqrt(fftOut_[j][0] * fftOut_[j][0] +
                          fftOut_[j][1] * fftOut_[j][1]) / halfSize;
        band += mag;
      }
      audioData_.bands[i] = band / (end - start);
    }

    for (int i = 0; i < 64 && i < halfSize; ++i) {
      double mag = std::sqrt(fftOut_[i][0] * fftOut_[i][0] +
                         fftOut_[i][1] * fftOut_[i][1]) / halfSize;
      audioData_.spectrum[i] = mag;
    }
  }

  void cleanup() {
    running_ = false;
    if (captureThread_.joinable()) {
      captureThread_.join();
    }
    if (pcmHandle_) {
      snd_pcm_close(pcmHandle_);
      pcmHandle_ = nullptr;
    }
    if (fftPlan_) {
      fftw_destroy_plan(fftPlan_);
      fftPlan_ = nullptr;
    }
    if (fftIn_)
      fftw_free(fftIn_);
    if (fftOut_)
      fftw_free(fftOut_);
  }

  AudioInput *parent_;
  snd_pcm_t *pcmHandle_;
  fftw_plan fftPlan_;
  double *fftIn_;
  fftw_complex *fftOut_;
  std::vector<float> inputBuffer_;
  std::vector<float> fftWindow_;

  int sampleRate_ = 44100;
  int bufferSize_ = 1024;

  std::atomic<bool> running_{false};
  std::thread captureThread_;

  std::string deviceName_;
  AudioData audioData_;
};

AudioInput::AudioInput() : impl_(new Impl(this)) {}
AudioInput::~AudioInput() = default;
bool AudioInput::initialize(int sampleRate, int bufferSize) {
  return impl_->initialize(sampleRate, bufferSize);
}
bool AudioInput::openDevice(const std::string &deviceName) {
  return impl_->openDevice(deviceName);
}
bool AudioInput::start() {
  impl_->start();
  return impl_->running_.load();
}
void AudioInput::stop() { impl_->stop(); }
bool AudioInput::isRunning() const { return impl_->running_.load(); }
AudioData AudioInput::getCurrentData() const { return impl_->audioData_; }

} // namespace Audio
} // namespace ShaderCandy

// Static method implementation for AudioInput
std::vector<std::string> ShaderCandy::Audio::AudioInput::getAvailableDevices() {
    std::vector<std::string> devices;
    
    // Add default device
    devices.push_back("default");
    
    // Enumerate ALSA devices
    void **hints;
    if (snd_device_name_hint(-1, "pcm", &hints) >= 0) {
        void **n = hints;
        while (*n != nullptr) {
            char *name = snd_device_name_get_hint(*n, "NAME");
            if (name != nullptr) {
                devices.push_back(std::string(name));
                free(name);
            }
            n++;
        }
        snd_device_name_free_hint(hints);
    }
    
    // Remove duplicates and sort
    std::sort(devices.begin(), devices.end());
    auto last = std::unique(devices.begin(), devices.end());
    devices.erase(last, devices.end());
    
    return devices;
}

bool ShaderCandy::Audio::AudioInput::selectDevice(const std::string &deviceName) {
    // Stop if currently running
    bool wasRunning = impl_->running_.load();
    if (wasRunning) {
        stop();
    }
    
    // Close current device if open
    if (impl_->pcmHandle_) {
        snd_pcm_close(impl_->pcmHandle_);
        impl_->pcmHandle_ = nullptr;
    }
    
    // Open the selected device
    bool success = impl_->openDevice(deviceName);
    
    // Restart if was running
    if (success && wasRunning) {
        start();
    }
    
    return success;
}