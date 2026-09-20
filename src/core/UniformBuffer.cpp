/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#include "UniformBuffer.h"
#include <ctime>

namespace ShaderCandy {

UniformBuffer::UniformBuffer()
    : data_{}, startTime_(std::chrono::high_resolution_clock::now()),
      lastFrameTime_(startTime_) {}

UniformBuffer::~UniformBuffer() = default;

void UniformBuffer::initialize() {
  startTime_ = std::chrono::high_resolution_clock::now();
  lastFrameTime_ = startTime_;
  data_.frame = 0;

  // Set date
  std::time_t now = std::time(nullptr);
  std::tm tm_buf;
  localtime_r(&now, &tm_buf);
  data_.date[0] = static_cast<float>(tm_buf.tm_year + 1900);
  data_.date[1] = static_cast<float>(tm_buf.tm_mon + 1);
  data_.date[2] = static_cast<float>(tm_buf.tm_mday);
  data_.date[3] = static_cast<float>(
      tm_buf.tm_hour * 3600 + tm_buf.tm_min * 60 + tm_buf.tm_sec);
}

void UniformBuffer::updateTime(float time) { data_.time = time; }

void UniformBuffer::updateResolution(float width, float height) {
  data_.resolution[0] = width;
  data_.resolution[1] = height;
}

void UniformBuffer::updateMouse(float x, float y) {
  data_.mouse[0] = x;
  data_.mouse[1] = y;
}

void UniformBuffer::updateFrame(int32_t frame) { data_.frame = frame; }

void UniformBuffer::updateDeltaTime(float dt) { data_.deltaTime = dt; }

void UniformBuffer::updateRayMarchLoD(int32_t maxSteps, float stepEpsilon,
                                      float lodScale) {
  data_.maxSteps = maxSteps;
  data_.stepEpsilon = stepEpsilon;
  data_.lodScale = lodScale;
}

void UniformBuffer::advanceFrame() {
  auto now = std::chrono::high_resolution_clock::now();

  // Calculate delta time
  auto delta = std::chrono::duration<float>(now - lastFrameTime_).count();
  data_.deltaTime = delta;

  // Calculate total time
  auto total = std::chrono::duration<float>(now - startTime_).count();
  data_.time = total;

  // Advance frame counter
  data_.frame++;

  // Update last frame time
  lastFrameTime_ = now;
}

} // namespace ShaderCandy
