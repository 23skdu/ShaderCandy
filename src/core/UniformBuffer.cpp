#include "UniformBuffer.h"
#include <ctime>

namespace ShaderCandy {

UniformBuffer::UniformBuffer() {
    // Zero initialize
    data_ = {};
    startTime_ = std::chrono::high_resolution_clock::now();
    lastFrameTime_ = startTime_;
}

UniformBuffer::~UniformBuffer() = default;

void UniformBuffer::initialize() {
    startTime_ = std::chrono::high_resolution_clock::now();
    lastFrameTime_ = startTime_;
    data_.frame = 0;
    
    // Set date
    std::time_t now = std::time(nullptr);
    std::tm* localTime = std::localtime(&now);
    data_.date[0] = static_cast<float>(localTime->tm_year + 1900);
    data_.date[1] = static_cast<float>(localTime->tm_mon + 1);
    data_.date[2] = static_cast<float>(localTime->tm_mday);
    data_.date[3] = static_cast<float>(localTime->tm_hour * 3600 + 
                                        localTime->tm_min * 60 + 
                                        localTime->tm_sec);
}

void UniformBuffer::updateTime(float time) {
    data_.time = time;
}

void UniformBuffer::updateResolution(float width, float height) {
    data_.resolution[0] = width;
    data_.resolution[1] = height;
}

void UniformBuffer::updateMouse(float x, float y) {
    data_.mouse[0] = x;
    data_.mouse[1] = y;
}

void UniformBuffer::updateFrame(int32_t frame) {
    data_.frame = frame;
}

void UniformBuffer::updateDeltaTime(float dt) {
    data_.deltaTime = dt;
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
