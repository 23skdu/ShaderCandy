#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace ShaderCandy {

// Display information
struct DisplayInfo {
  std::string id;    // Unique identifier
  std::string name;  // Human-readable name
  int x, y;          // Position
  int width, height; // Resolution
  int refreshRate;   // Hz
  bool isPrimary;    // Primary display?
  float scaleFactor; // DPI scale (1.0 = 96dpi)
};

// Display configuration
struct DisplayConfig {
  std::string displayId;
  std::string shaderName;
  bool enabled;
  int targetFPS;
  bool useHDR;
};

class MultiDisplayManager {
public:
  static MultiDisplayManager &getInstance();

  // Initialization
  bool initialize();
  void shutdown();

  // Display enumeration
  std::vector<DisplayInfo> getDisplays() const;
  DisplayInfo getPrimaryDisplay() const;
  DisplayInfo getDisplay(const std::string &id) const;

  // Configuration
  void setDisplayShader(const std::string &displayId,
                        const std::string &shaderName);
  std::string getDisplayShader(const std::string &displayId) const;
  void setDisplayEnabled(const std::string &displayId, bool enabled);
  bool isDisplayEnabled(const std::string &displayId) const;

  // Spanning modes
  enum class SpanMode {
    Single,     // One shader per display
    SpanAll,    // One shader stretched across all
    Clone,      // Same shader on all displays
    Independent // Each display runs independently
  };

  void setSpanMode(SpanMode mode);
  SpanMode getSpanMode() const;

  // Virtual display for spanning
  int getVirtualWidth() const;
  int getVirtualHeight() const;
  float getVirtualAspectRatio() const;

  // Coordinate conversion
  void virtualToDisplay(float vx, float vy, const std::string &displayId,
                        float &dx, float &dy) const;
  void displayToVirtual(const std::string &displayId, float dx, float dy,
                        float &vx, float &vy) const;

  // Synchronization
  void synchronizeTime(double time);
  double getSynchronizedTime() const;

  // Change notifications
  using DisplayChangeCallback =
      std::function<void(const std::vector<DisplayInfo> &)>;
  void setDisplayChangeCallback(DisplayChangeCallback callback);

  // Platform-specific implementation
  class Impl;

private:
  MultiDisplayManager();
  ~MultiDisplayManager();

  std::unique_ptr<Impl> pImpl;
  std::vector<DisplayConfig> configs_;
  SpanMode spanMode_ = SpanMode::Independent;
  double syncTime_ = 0.0;
};

// Headless/Offscreen rendering support
class HeadlessRenderer {
public:
  HeadlessRenderer();
  ~HeadlessRenderer();

  // Initialization
  bool initialize(int width, int height);
  void shutdown();

  // Render settings
  void setShader(const std::string &shaderName);
  void setDuration(float seconds);
  void setFPS(int fps);
  void setOutputFormat(const std::string &format); // "png", "jpg", "mp4", "raw"

  // Render to file
  bool renderToFile(const std::string &outputPath);

  // Render to memory buffer
  std::vector<uint8_t> renderToBuffer(int frame);

  // Frame-by-frame rendering
  void beginRender();
  bool renderFrame();
  bool isFinished() const;
  void endRender();

  // Progress callback
  using ProgressCallback =
      std::function<void(int currentFrame, int totalFrames)>;
  void setProgressCallback(ProgressCallback callback);

  // Video encoding
  bool startVideoEncoding(const std::string &outputPath, int fps);
  bool encodeFrame(const std::vector<uint8_t> &frameData);
  void finishVideoEncoding();

  // GPU selection
  void setGPUDevice(int deviceIndex);
  std::vector<std::string> getAvailableGPUs() const;

private:
  class Impl;
  std::unique_ptr<Impl> pImpl;

  int width_ = 1920;
  int height_ = 1080;
  float duration_ = 10.0f;
  int fps_ = 60;
  std::string outputFormat_ = "png";
  std::string currentShader_;
  int currentFrame_ = 0;
  int totalFrames_ = 0;
};

// Utility functions
namespace DisplayUtils {
// Calculate optimal texture size for a display
int getOptimalTextureSize(int displayWidth, int displayHeight, float quality);

// Check if displays form a continuous desktop
bool areDisplaysContiguous(const std::vector<DisplayInfo> &displays);

// Calculate bounding box of all displays
void getBoundingBox(const std::vector<DisplayInfo> &displays, int &minX,
                    int &minY, int &maxX, int &maxY);

// Check for display configuration changes
bool hasConfigurationChanged(const std::vector<DisplayInfo> &oldConfig,
                             const std::vector<DisplayInfo> &newConfig);
} // namespace DisplayUtils

} // namespace ShaderCandy
