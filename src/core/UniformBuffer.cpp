/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#include "UniformBuffer.h"
#include <cmath>
#include <ctime>

namespace ShaderCandy {

namespace {
float sanitizeFinite(float value, float fallback = 0.0f) {
  return std::isfinite(value) ? value : fallback;
}
} // namespace

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
  std::tm tm_buf{};
  std::tm *timeInfo = localtime_r(&now, &tm_buf);
  if (timeInfo != nullptr) {
    data_.date[0] = static_cast<float>(tm_buf.tm_year + 1900);
    data_.date[1] = static_cast<float>(tm_buf.tm_mon + 1);
    data_.date[2] = static_cast<float>(tm_buf.tm_mday);
    data_.date[3] = static_cast<float>(
        tm_buf.tm_hour * 3600 + tm_buf.tm_min * 60 + tm_buf.tm_sec);
  } else {
    data_.date[0] = 0.0f;
    data_.date[1] = 0.0f;
    data_.date[2] = 0.0f;
    data_.date[3] = 0.0f;
  }
}

void UniformBuffer::updateTime(float time) { data_.time = sanitizeFinite(time); }

void UniformBuffer::updateResolution(float width, float height) {
  data_.resolution[0] = sanitizeFinite(width, 0.0f);
  data_.resolution[1] = sanitizeFinite(height, 0.0f);
}

void UniformBuffer::updateMouse(float x, float y) {
  data_.mouse[0] = sanitizeFinite(x, 0.0f);
  data_.mouse[1] = sanitizeFinite(y, 0.0f);
}

void UniformBuffer::updateFrame(int32_t frame) { data_.frame = frame; }

void UniformBuffer::updateDeltaTime(float dt) {
  data_.deltaTime = sanitizeFinite(dt, 0.0f);
}

void UniformBuffer::updateRayMarchLoD(int32_t maxSteps, float stepEpsilon,
                                      float lodScale) {
  data_.maxSteps = maxSteps;
  data_.stepEpsilon = sanitizeFinite(stepEpsilon, 0.0f);
  data_.lodScale = sanitizeFinite(lodScale, 1.0f);
}

void UniformBuffer::advanceFrame() {
  auto now = std::chrono::high_resolution_clock::now();

  // Calculate delta time
  auto delta = std::chrono::duration<float>(now - lastFrameTime_).count();
  data_.deltaTime = sanitizeFinite(delta, 0.0f);

  // Calculate total time
  auto total = std::chrono::duration<float>(now - startTime_).count();
  data_.time = sanitizeFinite(total, 0.0f);

  // Advance frame counter
  data_.frame++;

  // Update last frame time
  lastFrameTime_ = now;
}

} // namespace ShaderCandy
