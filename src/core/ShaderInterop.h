#ifndef SHADER_INTEROP_H
#define SHADER_INTEROP_H

#include <cstdint>

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
#define ATTR(n) [[attribute(n)]]
#define POSITION [[position]]
#else
// Platform-specific SIMD types
#if defined(__APPLE__)
#include <simd/simd.h>
typedef simd_float2 vector_float2;
typedef simd_float3 vector_float3;
typedef simd_float4 vector_float4;
#else
// Linux/non-Apple platforms - define our own vector types
typedef struct {
  float x;
  float y;
} vector_float2;
typedef struct {
  float x;
  float y;
  float z;
} vector_float3;
typedef struct {
  float x;
  float y;
  float z;
  float w;
} vector_float4;
#endif
#define ATTR(n)
#define POSITION
#endif

// Shared uniform structure
struct Uniforms {
  float time;
  float speed;
  vector_float2 resolution;
  vector_float2 mouse;
  float mouseButtons;
  float intensity;
  vector_float4 date;
  int32_t frame;
  float deltaTime;
  float alpha;
  float gravity;

  // Audio data
  float volume;
  float bass;
  float mid;
  float treble;
  float beat;
  float audioData[256];

  // Performance metrics
  float gpuTime;
  float cpuTime;
  float fps;
};

// Shared vertex input structure
struct VertexIn {
  vector_float2 position ATTR(0);
  vector_float2 texCoord ATTR(1);
};

// Shared vertex output structure
struct VertexOut {
  vector_float4 position POSITION;
  vector_float2 texCoord;
};

// Particle structure for compute/vertex buffers
typedef struct {
  vector_float2 position;
  vector_float2 velocity;
  vector_float4 color;
  float life;
  float size;
  vector_float2 padding;
} Particle;

#endif // SHADER_INTEROP_H
