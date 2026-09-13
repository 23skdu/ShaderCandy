#pragma once

#include <chrono>
#include <cstdint>

namespace ShaderCandy {

// Uniform data structure matching shader layout
struct UniformData {
  float time;
  float resolution[2];
  float mouse[2];
  float date[4]; // year, month, day, seconds
  int32_t frame;
  float deltaTime;
  float lodScale = 1.0f;
  int32_t maxSteps = 128;
  float stepEpsilon = 0.001f;
  float padding[1];
};

class UniformBuffer {
public:
  UniformBuffer();
  ~UniformBuffer();

  // Update uniform values
  void updateTime(float time);
  void updateResolution(float width, float height);
  void updateMouse(float x, float y);
  void updateFrame(int32_t frame);
  void updateDeltaTime(float dt);
  void updateRayMarchLoD(int32_t maxSteps, float stepEpsilon, float lodScale = 1.0f);

  int32_t getMaxSteps() const { return data_.maxSteps; }
  float getStepEpsilon() const { return data_.stepEpsilon; }
  float getLodScale() const { return data_.lodScale; }

  // Get current uniform data
  const UniformData &getData() const { return data_; }
  UniformData &getData() { return data_; }

  // Size of uniform buffer
  static constexpr size_t size() { return sizeof(UniformData); }

  // Initialize at startup
  void initialize();

  // Advance frame
  void advanceFrame();

private:
  UniformData data_;
  std::chrono::high_resolution_clock::time_point startTime_;
  std::chrono::high_resolution_clock::time_point lastFrameTime_;
};

} // namespace ShaderCandy
