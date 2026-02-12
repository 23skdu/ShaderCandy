#import "AudioInput.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>

@interface AudioDelegate
    : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>
@property(nonatomic, assign) ShaderCandy::Audio::AudioInput *parent;
@property(nonatomic, assign) int bufferSize;
@end

@implementation AudioDelegate {
  FFTSetup _fftSetup;
  DSPSplitComplex _splitComplex;
  int _log2n;
  std::vector<float> _window;
}

- (instancetype)initWithBufferSize:(int)bufferSize {
  self = [super init];
  if (self) {
    _bufferSize = bufferSize;
    [self setupFFT];
  }
  return self;
}

- (void)dealloc {
  [self destroyFFT];
}

- (void)setupFFT {
  _log2n = (int)log2(_bufferSize);
  _fftSetup = vDSP_create_fftsetup(_log2n, FFT_RADIX2);

  _splitComplex.realp = (float *)malloc(_bufferSize / 2 * sizeof(float));
  _splitComplex.imagp = (float *)malloc(_bufferSize / 2 * sizeof(float));

  _window.resize(_bufferSize);
  vDSP_hann_window(_window.data(), _bufferSize,
                   vDSP_HANN_NORM); // Fixed alias/constant
}

- (void)destroyFFT {
  if (_fftSetup) {
    vDSP_destroy_fftsetup(_fftSetup);
    _fftSetup = nullptr;
  }
  if (_splitComplex.realp)
    free(_splitComplex.realp);
  if (_splitComplex.imagp)
    free(_splitComplex.imagp);
}

- (void)captureOutput:(AVCaptureOutput *)output
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {

  CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
  if (!blockBuffer)
    return;

  size_t totalLength;
  char *data;
  if (CMBlockBufferGetDataPointer(blockBuffer, 0, nullptr, &totalLength,
                                  &data) != kCMBlockBufferNoErr) {
    return;
  }

  // ShaderCandy expects float data. We assume 32-bit float mono for now.
  // In a real implementation, we should check
  // CMSampleBufferGetFormatDescription
  float *floatData = (float *)data;
  size_t numSamples = totalLength / sizeof(float);

  if (numSamples < (size_t)_bufferSize)
    return;

  std::vector<float> samples(floatData, floatData + _bufferSize);
  self.parent->performFFT(samples);
}

- (void)processFFT:(const std::vector<float> &)samples
            toData:(ShaderCandy::Audio::AudioData &)data {
  // Apply window
  std::vector<float> windowedSamples(_bufferSize);
  vDSP_vmul(samples.data(), 1, _window.data(), 1, windowedSamples.data(), 1,
            _bufferSize);

  // Pack into split complex
  vDSP_ctoz((DSPComplex *)windowedSamples.data(), 2, &_splitComplex, 1,
            _bufferSize / 2);

  // Perform FFT
  vDSP_fft_zrip(_fftSetup, &_splitComplex, 1, _log2n, FFT_FORWARD);

  // Magnitude
  data.spectrum.resize(_bufferSize / 2);
  vDSP_zvmags(&_splitComplex, 1, data.spectrum.data(), 1, _bufferSize / 2);

  // Scaling
  float scale = 1.0f / (float)(_bufferSize * 2);
  vDSP_vsmul(data.spectrum.data(), 1, &scale, data.spectrum.data(), 1,
             _bufferSize / 2);

  // Square root to get magnitude
  for (float &freq : data.spectrum) {
    freq = sqrtf(freq);
  }
}

@end

namespace ShaderCandy {
namespace Audio {

class AudioInput::Impl {
public:
  Impl(AudioInput *parent) : parent_(parent) {
    delegate_ = [[AudioDelegate alloc] initWithBufferSize:1024];
    delegate_.parent = parent;
  }

  bool initialize(int sampleRate, int bufferSize) {
    sampleRate_ = sampleRate;
    if (bufferSize != delegate_.bufferSize) {
      delegate_ = [[AudioDelegate alloc] initWithBufferSize:bufferSize];
      delegate_.parent = parent_;
    }

    AVCaptureDevice *audioDevice =
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (!audioDevice)
      return false;

    NSError *error = nil;
    AVCaptureDeviceInput *audioInput =
        [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (!audioInput)
      return false;

    captureSession_ = [[AVCaptureSession alloc] init];
    if ([captureSession_ canAddInput:audioInput]) {
      [captureSession_ addInput:audioInput];
    }

    AVCaptureAudioDataOutput *audioOutput =
        [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioQueue = dispatch_queue_create(
        "com.shadercandy.audioQueue", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:delegate_ queue:audioQueue];

    if ([captureSession_ canAddOutput:audioOutput]) {
      [captureSession_ addOutput:audioOutput];
    }

    return true;
  }

  void start() {
    if (captureSession_ && !captureSession_.running) {
      [captureSession_ startRunning];
    }
  }

  void stop() {
    if (captureSession_ && captureSession_.running) {
      [captureSession_ stopRunning];
    }
  }

  void handleFFT(const std::vector<float> &samples, AudioData &data) {
    [delegate_ processFFT:samples toData:data];
  }

private:
  AudioInput *parent_;
  AVCaptureSession *captureSession_;
  AudioDelegate *delegate_;
  int sampleRate_;
};

AudioInput::AudioInput()
    : pImpl(std::make_unique<Impl>(this)), sampleRate_(44100),
      bufferSize_(1024), smoothing_(0.8f), beatThreshold_(0.1f) {
  running_ = false;
}

AudioInput::~AudioInput() { stop(); }

bool AudioInput::initialize(int sampleRate, int bufferSize) {
  return pImpl->initialize(sampleRate, bufferSize);
}

void AudioInput::start() {
  pImpl->start();
  running_ = true;
}

void AudioInput::stop() {
  pImpl->stop();
  running_ = false;
}

bool AudioInput::isRunning() const { return running_; }

void AudioInput::setCallback(AudioCallback callback) {
  std::lock_guard<std::mutex> lock(dataMutex_);
  callback_ = callback;
}

void AudioInput::performFFT(const std::vector<float> &samples) {
  std::lock_guard<std::mutex> lock(dataMutex_);

  currentData_.waveform = samples;

  float rms = 0;
  vDSP_rmsqv(samples.data(), 1, &rms, samples.size());
  currentData_.volume = rms;
  currentData_.volumeSmoothed =
      currentData_.volumeSmoothed * smoothing_ + rms * (1.0f - smoothing_);

  pImpl->handleFFT(samples, currentData_);
  analyzeFrequencyBands();
  detectBeat();

  if (callback_) {
    callback_(currentData_);
  }
}

void AudioInput::analyzeFrequencyBands() {
  if (currentData_.spectrum.empty())
    return;

  int numBins = (int)currentData_.spectrum.size();
  int binsPerBand = numBins / AudioData::NUM_BANDS;

  for (int i = 0; i < AudioData::NUM_BANDS; i++) {
    float bandSum = 0;
    int count = 0;
    for (int j = 0; j < binsPerBand && (i * binsPerBand + j) < numBins; j++) {
      bandSum += currentData_.spectrum[i * binsPerBand + j];
      count++;
    }
    currentData_.bands[i] = count > 0 ? (bandSum / count) : 0;
  }

  currentData_.bass = currentData_.bands[0];
  currentData_.mid = currentData_.bands[3];
  currentData_.treble = currentData_.bands[7];
}

void AudioInput::detectBeat() {
  static float prevBass = 0;
  float bassEnergy = currentData_.bass;
  float diff = bassEnergy - prevBass;

  currentData_.beat = (diff > beatThreshold_);
  currentData_.beatIntensity = diff > 0 ? diff : 0;

  prevBass = bassEnergy;
}

AudioData AudioInput::getCurrentData() const {
  std::lock_guard<std::mutex> lock(dataMutex_);
  return currentData_;
}

std::vector<std::string> AudioInput::getAvailableDevices() {
  return {"Default Input"};
}

bool AudioInput::selectDevice(const std::string &deviceName) { return true; }

bool AudioInput::autoSelectDevice() { return true; }

#pragma mark - Utils

namespace Utils {
void packAudioForShader(const AudioData &audio, float *output, int maxSamples) {
  if (audio.spectrum.empty())
    return;
  int count = std::min((int)audio.spectrum.size(), maxSamples);
  for (int i = 0; i < count; i++) {
    output[i] = audio.spectrum[i];
  }
}

float getDominantFrequency(const AudioData &audio) {
  if (audio.spectrum.empty())
    return 0;
  auto it = std::max_element(audio.spectrum.begin(), audio.spectrum.end());
  return (float)std::distance(audio.spectrum.begin(), it);
}

float getSpectralCentroid(const AudioData &audio) {
  if (audio.spectrum.empty())
    return 0;
  float weightedSum = 0;
  float totalSum = 0;
  for (size_t i = 0; i < audio.spectrum.size(); i++) {
    weightedSum += i * audio.spectrum[i];
    totalSum += audio.spectrum[i];
  }
  return totalSum > 0 ? (weightedSum / totalSum) : 0;
}

bool bandHasEnergy(const AudioData &audio, int band, float threshold) {
  if (band < 0 || band >= AudioData::NUM_BANDS)
    return false;
  return audio.bands[band] > threshold;
}
} // namespace Utils

} // namespace Audio
} // namespace ShaderCandy
