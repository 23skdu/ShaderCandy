/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#pragma once

#include <chrono>
#include <cstdint>
#include <mutex>

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

  // Declared here so it can be defaulted; std::mutex is not trivially
  // destructible, which is exactly why an implicit destructor would not work.
  ~UniformBuffer() = default;

  // Update uniform values
  void updateTime(float time);
  void updateResolution(float width, float height);
  void updateMouse(float x, float y);
  void updateFrame(int32_t frame);
  void updateDeltaTime(float dt);
  void updateRayMarchLoD(int32_t maxSteps, float stepEpsilon, float lodScale = 1.0f);

  int32_t getMaxSteps() const;
  float getStepEpsilon() const;
  float getLodScale() const;

  // Snapshot of the current uniform data.
  //
  // Thread-safe: the struct is copied under the lock. Returning a reference to
  // the live member (as this class used to) cannot be made safe, because a
  // caller holding that reference could be reading it while updateX() writes.
  UniformData getData() const;
  void setData(const UniformData &d);

  // Size of uniform buffer
  static constexpr size_t size() { return sizeof(UniformData); }

  // Initialize at startup
  void initialize();

  // Advance frame
  void advanceFrame();

private:
  // Guards data_, startTime_ and lastFrameTime_. The render thread writes
  // uniforms while background threads (input, IPC, audio) may read them.
  mutable std::mutex mutex_;
  UniformData data_;
  std::chrono::high_resolution_clock::time_point startTime_;
  std::chrono::high_resolution_clock::time_point lastFrameTime_;
};

} // namespace ShaderCandy
