# Shader Authoring Guide

This guide explains how to create new shaders for ShaderCandy, covering both Metal (macOS) and GLSL (Linux) implementations.

## Table of Contents

1. [Overview](#overview)
2. [Shader Types](#shader-types)
3. [Creating Your First Shader](#creating-your-first-shader)
4. [Shared Utilities](#shared-utilities)
5. [Best Practices](#best-practices)
6. [Platform-Specific Considerations](#platform-specific-considerations)
7. [Testing and Debugging](#testing-and-debugging)
8. [Examples](#examples)

## Overview

ShaderCandy supports two shader languages:
- **Metal** (macOS): `.metal` files compiled at runtime or build time
- **GLSL** (Linux): `.frag` fragment shaders compiled at runtime

All shaders follow a consistent structure and use shared utility functions for noise, SDFs, and math operations.

## Shader Types

### 1. Fragment Shaders (Most Common)
- Full-screen post-processing effects
- Raymarching scenes
- Procedural generation

### 2. Compute Shaders (Advanced)
- Particle systems
- Simulation passes
- Image processing

### 3. Vertex Shaders (Rare)
- Custom geometry rendering
- (Usually use default fullscreen quad)

## Creating Your First Shader

### Step 1: Choose Your Platform

Create files in `shaders/effects/`:
- `my_shader.metal` (Metal)
- `my_shader.frag` (GLSL)

### Step 2: Basic Metal Shader Structure

```metal
// my_shader.metal
#include "base/common.metal"

// Uniform buffer (auto-injected by ShaderManager)
// struct Uniforms {
//     float time;
//     float2 resolution;
//     float2 mouse;
//     float4 date;
//     int frame;
//     float deltaTime;
// };

fragment float4 my_shader_main(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    // Normalized pixel coordinates (from 0 to 1)
    float2 uv = in.texCoord;
    
    // Time variable
    float time = uniforms.time;
    
    // Your shader logic here
    float3 color = float3(uv.x, uv.y, 0.5 + 0.5 * sin(time));
    
    return float4(color, 1.0);
}
```

### Step 3: Basic GLSL Shader Structure

```glsl
// my_shader.frag
#version 330 core

uniform float time;
uniform vec2 resolution;
uniform vec2 mouse;
uniform vec4 date;
uniform int frame;
uniform float deltaTime;

in vec2 texCoord;
out vec4 fragColor;

void main() {
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = texCoord;
    
    // Time variable
    float t = time;
    
    // Your shader logic here
    vec3 color = vec3(uv.x, uv.y, 0.5 + 0.5 * sin(t));
    
    fragColor = vec4(color, 1.0);
}
```

## Shared Utilities

### Noise Functions

ShaderCandy provides comprehensive noise functions in `shaders/base/common.metal` and `shaders/base/common.glsl`:

```metal
// 2D Value Noise
float noise2d = ShaderUtils::noise(uv * 5.0);

// 3D Simplex Noise
float noise3d = ShaderUtils::snoise(vec3(uv * 5.0, time * 0.5));

// Fractal Brownian Motion (FBM)
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 6; i++) {
        value += amplitude * ShaderUtils::noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}
```

### Signed Distance Functions (SDFs)

For raymarching shaders, use the SDF primitives:

```metal
// Basic primitives
float sphereSDF(vec3 p, float radius) {
    return length(p) - radius;
}

float boxSDF(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float torusSDF(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Boolean operations
float unionSDF(float d1, float d2) {
    return min(d1, d2);
}

float intersectionSDF(float d1, float d2) {
    return max(d1, d2);
}

float subtractionSDF(float d1, float d2) {
    return max(-d1, d2);
}
```

### Math Utilities

```metal
// Rotation matrices
mat2 rotate2d(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat2(c, -s, s, c);
}

mat3 rotate3d(vec3 axis, float angle) {
    // Implementation based on axis-angle rotation
    // See ShaderUtils in common.metal for full implementation
}

// Color utilities
vec3 rgb2hsv(vec3 c) {
    // RGB to HSV conversion
}

vec3 hsv2rgb(vec3 c) {
    // HSV to RGB conversion
}
```

## Best Practices

### 1. Performance Optimization

**Use branchless programming when possible:**
```metal
// Bad: Branching in shader
if (condition) {
    color = vec3(1.0, 0.0, 0.0);
} else {
    color = vec3(0.0, 0.0, 1.0);
}

// Good: Use mix() function
color = mix(vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), float(condition));
```

**Minimize texture lookups:**
```metal
// Cache repeated calculations
float2 uv = in.texCoord;
float2 scaledUV = uv * 5.0;  // Calculate once
float n1 = ShaderUtils::noise(scaledUV);
float n2 = ShaderUtils::noise(scaledUV * 2.0);  // Reuse scaledUV
```

### 2. Code Organization

**Use functions for reusable logic:**
```metal
float3 palette(float t) {
    // Cosine-based color palette
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.263, 0.416, 0.557);
    return a + b * cos(6.28318 * (c * t + d));
}
```

**Document complex algorithms:**
```metal
/**
 * Raymarches a scene starting from ray origin
 * @param ro - Ray origin
 * @param rd - Ray direction
 * @param maxSteps - Maximum number of marching steps
 * @param maxDist - Maximum marching distance
 * @return Distance to nearest surface or maxDist if no hit
 */
float raymarch(vec3 ro, vec3 rd, int maxSteps, float maxDist) {
    float t = 0.0;
    for (int i = 0; i < maxSteps; i++) {
        float d = sceneSDF(ro + rd * t);
        if (d < 0.001 || t > maxDist) break;
        t += d;
    }
    return t;
}
```

### 3. Time Management

**Use deltaTime for frame-rate independent animations:**
```metal
// Bad: Frame-dependent animation
float x = sin(uniforms.time * 2.0);

// Good: Frame-rate independent (using deltaTime if available)
float x = sin(uniforms.time * 2.0);
// Or for physics-based animations:
float velocity = 100.0; // pixels per second
position += velocity * uniforms.deltaTime;
```

### 4. Mouse Interaction

**Normalize mouse coordinates:**
```metal
// Mouse position in normalized coordinates (0-1)
float2 mouseUV = uniforms.mouse / uniforms.resolution;

// Mouse position in centered coordinates (-1 to 1)
float2 mouseCentered = (uniforms.mouse / uniforms.resolution) * 2.0 - 1.0;
```

## Platform-Specific Considerations

### Metal (macOS)

**Data types:**
- `float2`, `float3`, `float4` (vector types)
- `half` for memory-constrained scenarios
- `texture2d` for texture sampling

**Sampler states:**
```metal
// Default sampler
constexpr sampler s(coord::normalized, address::repeat, filter::linear);

// Usage
float4 color = texture.sample(s, uv);
```

**Vertex output structure:**
```metal
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float2 screenPos;
};
```

### GLSL (Linux)

**Version requirements:**
- Minimum: `#version 330 core`
- Recommended: `#version 450` for modern features

**Data types:**
- `vec2`, `vec3`, `vec4`
- `mat2`, `mat3`, `mat4`
- `sampler2D` for texture sampling

**Texture sampling:**
```glsl
uniform sampler2D tex;
vec4 color = texture(tex, uv);
```

## Testing and Debugging

### 1. Compile-Time Testing

**Metal compilation:**
```bash
xcrun -sdk macosx metal -c shader.metal -o shader.air
xcrun -sdk macosx metallib shader.air -o shader.metallib
```

**GLSL compilation:**
```bash
glslangValidator -S frag shader.frag
```

### 2. Runtime Testing

**Use the test suite:**
```bash
./shadercandy-test --run "Shader Compilation Tests"
```

**Debug output:**
```metal
// Add debug colors to visualize different passes
#ifdef DEBUG
    return float4(debugColor, 1.0);
#endif
```

### 3. Performance Profiling

**Use the PerformanceMonitor:**
```metal
// Automatically tracked by the engine
// Check FPS, frame times in real-time overlay
```

### 4. Common Issues

**Issue: Shader compiles but shows black/white**
- Check UV coordinates are in range [0,1]
- Verify time variable is being updated
- Check for division by zero

**Issue: Performance is poor**
- Reduce loop iterations
- Use simpler noise functions
- Minimize texture lookups
- Use branchless programming

**Issue: Different appearance on Metal vs GLSL**
- Check data type precision differences
- Verify coordinate systems match
- Test with simple color output first

## Examples

### Example 1: Simple Gradient Shader

**Metal:**
```metal
fragment float4 gradient_main(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float3 color = float3(uv.x, uv.y, 0.5 + 0.5 * sin(uniforms.time));
    return float4(color, 1.0);
}
```

**GLSL:**
```glsl
void main() {
    vec2 uv = texCoord;
    vec3 color = vec3(uv.x, uv.y, 0.5 + 0.5 * sin(time));
    fragColor = vec4(color, 1.0);
}
```

### Example 2: Raymarching Sphere

**Metal:**
```metal
float sphereSDF(vec3 p, float radius) {
    return length(p) - radius;
}

fragment float4 sphere_main(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = (in.texCoord * 2.0 - 1.0);
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    vec3 ro = vec3(0.0, 0.0, -3.0);
    vec3 rd = normalize(vec3(uv, 1.0));
    
    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        vec3 p = ro + rd * t;
        float d = sphereSDF(p, 1.0);
        if (d < 0.001) break;
        t += d;
    }
    
    vec3 color = vec3(0.0);
    if (t < 10.0) {
        vec3 p = ro + rd * t;
        vec3 normal = normalize(p);
        float lighting = dot(normal, normalize(vec3(1.0, 1.0, 1.0)));
        color = vec3(0.5 + 0.5 * lighting);
    }
    
    return float4(color, 1.0);
}
```

### Example 3: Audio-Reactive Shader

**Metal:**
```metal
fragment float4 audio Reactive_main(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]],
    constant AudioData &audio [[buffer(1)]]
) {
    float2 uv = in.texCoord;
    
    // Get audio data (bass, mid, treble)
    float bass = audio.bassLevel;
    float mid = audio.midLevel;
    float treble = audio.trebleLevel;
    
    // Create audio-reactive pattern
    float wave = sin(uv.x * 10.0 + bass * 5.0) * 0.5 + 0.5;
    float3 color = float3(wave * mid, uv.y * treble, bass);
    
    return float4(color, 1.0);
}
```

## Adding Your Shader to the Library

1. **Place files in `shaders/effects/`**
   - `your_shader.metal`
   - `your_shader.frag`

2. **Update shader catalog**
   - Add entry to `docs/shaders.md`
   - Include description and category

3. **Test compilation**
   ```bash
   ./shadercandy-test --run "Shader Compilation Tests"
   ```

4. **Verify visual output**
   - Use standalone player to preview
   - Check on both Metal and GLSL backends

## Conclusion

Creating shaders for ShaderCandy follows a consistent pattern across both Metal and GLSL. By using the shared utilities and following best practices, you can create efficient, cross-platform shaders that work seamlessly on both macOS and Linux.

For more examples, see the existing shaders in `shaders/effects/` and the shader catalog in `docs/shaders.md`.
