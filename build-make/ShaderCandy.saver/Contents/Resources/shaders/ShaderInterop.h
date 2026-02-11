#ifndef SHADER_INTEROP_H
#define SHADER_INTEROP_H

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
#define ATTR(n) [[attribute(n)]]
#define POSITION [[position]]
#else
#include <simd/simd.h>
#define ATTR(n)
#define POSITION
typedef simd_float2 vector_float2;
typedef simd_float3 vector_float3;
typedef simd_float4 vector_float4;
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
