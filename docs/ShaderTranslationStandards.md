# Shader Translation Standards: Metal to GLSL

This document defines the standards for translating Metal shaders to GLSL for Linux/OpenGL compatibility.

## Overview

ShaderCandy uses a unified shader architecture where Metal shaders (`.metal`) are the source of truth for macOS, and GLSL fragment shaders (`.frag`) provide Linux/OpenGL compatibility. This guide ensures consistent translation between the two languages.

## Type Mappings

### Scalar and Vector Types

| Metal Type | GLSL Type | Description |
|------------|-----------|-------------|
| `float` | `float` | Single precision float |
| `float2` | `vec2` | 2-component vector |
| `float3` | `vec3` | 3-component vector |
| `float4` | `vec4` | 4-component vector |
| `int` | `int` | Integer |
| `int2` | `ivec2` | 2-component integer vector |
| `bool` | `bool` | Boolean |
| `half` | `float` | Half precision (use float in GLSL) |

### Matrix Types

| Metal Type | GLSL Type | Description |
|------------|-----------|-------------|
| `float2x2` | `mat2` | 2x2 matrix |
| `float3x3` | `mat3` | 3x3 matrix |
| `float4x4` | `mat4` | 4x4 matrix |

## Function Entry Points

### Metal Structure
```metal
fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    // ... shader code
    return float4(color, 1.0);
}
```

### GLSL Structure
```glsl
#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    // ... shader code
    return vec4(color, 1.0);
}
```

**Key Differences:**
- Metal uses `fragment_main` entry point with parameters
- GLSL uses `effect_main` function signature matching the template in `common.glsl`
- GLSL must include `common.glsl` at the top
- Metal parameters are passed via `uniforms.*`, GLSL uses global uniforms

## Uniform Access

### Metal Access Pattern
```metal
float t = uniforms.time * uniforms.speed;
float2 uv = in.texCoord;
float aspect = uniforms.resolution.x / uniforms.resolution.y;
```

### GLSL Access Pattern
```glsl
float t = time * speed;  // Note: no 'uniforms.' prefix
vec2 uv = vTexCoord;     // Passed as parameter to effect_main
float aspect = resolution.x / resolution.y;
```

**Important:** In GLSL, uniforms are global variables declared in `common.glsl`. Do NOT prefix with `uniforms.`.

## Swizzling and Component Access

Both languages support swizzling:
- Metal: `pos.xy`, `color.rgb`, `texCoord.x`
- GLSL: `pos.xy`, `color.rgb`, `uv.x`

## Built-in Functions

### Most functions are identical:
- `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
- `pow`, `exp`, `log`, `sqrt`, `abs`, `sign`
- `min`, `max`, `clamp`, `mix`, `step`, `smoothstep`
- `length`, `distance`, `dot`, `cross`, `normalize`, `reflect`, `refract`
- `floor`, `ceil`, `fract`, `mod`

### Notable Differences:

| Metal | GLSL | Notes |
|-------|------|-------|
| `saturate(x)` | `clamp(x, 0.0, 1.0)` | Clamp to 0-1 range |
| `rsqrt(x)` | `inversesqrt(x)` | Reciprocal square root |
| `fmod(x, y)` | `mod(x, y)` | Floating-point modulo |
| `select(a, b, cond)` | `cond ? b : a` | Component-wise selection |

## Vertex Input/Output

### Metal VertexOut Structure
```metal
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float2 screenPos;
};
```

### GLSL Input (via common.glsl)
```glsl
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vScreenPos;
```

**Important:** `effect_main` receives `centered` (NDC space, aspect-corrected) and `uv` (0-1 texture space) as parameters.

## Coordinate System Handling

### UV Coordinate Conversion

**Metal:**
```metal
float2 uv = in.texCoord * 2.0 - 1.0;  // Convert 0-1 to -1 to 1
uv.x *= uniforms.resolution.x / uniforms.resolution.y;  // Aspect correction
```

**GLSL:**
```glsl
// Handled automatically in main():
// vec2 centered = uv * 2.0 - 1.0;
// centered.x *= resolution.x / resolution.y;
//
// Use 'centered' for aspect-corrected NDC coordinates
// Use 'uv' for 0-1 texture coordinates
```

## Texture Sampling

### Metal
```metal
texture2d<float> prevFrame [[texture(0)]];
sampler frameSampler [[sampler(0)]];
float4 sample = prevFrame.sample(frameSampler, uv);
```

### GLSL
```glsl
// sampler2D prevFrame is declared in common.glsl
vec4 sample = texture(prevFrame, uv);
```

## Translation Checklist

When porting a Metal shader to GLSL:

1. **Create new file** with `.frag` extension
2. **Add include** at top: `#include "../base/common.glsl"`
3. **Change entry point** from `fragment_main` to `effect_main`
4. **Remove Metal attributes**: Delete `[[stage_in]]`, `[[buffer(0)]]`, `[[position]]`
5. **Remove uniforms prefix**: Change `uniforms.time` to `time`
6. **Replace types**: `float2`→`vec2`, `float3`→`vec3`, `float4`→`vec4`
7. **Use correct UV**: Replace `in.texCoord` with parameter `uv` or `centered`
8. **Return value**: Return `vec4` from `effect_main`
9. **Test compilation**: Verify with glslangValidator

## Example: Complete Translation

### Original Metal (plasma.metal)
```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.5;
    
    float v = sin(uv.x * 10.0 + t);
    v += sin(uv.y * 10.0 + t * 1.2);
    v += sin((uv.x + uv.y) * 10.0 + t * 0.8);
    v += sin(length(uv) * 10.0 + t * 1.5);
    v *= 0.25;
    
    float3 color = float3(
        0.5 + 0.5 * sin(v * 3.14159 + t),
        0.5 + 0.5 * sin(v * 3.14159 + t + 2.0),
        0.5 + 0.5 * sin(v * 3.14159 + t + 4.0)
    );
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
```

### Translated GLSL (plasma.frag)
```glsl
#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    
    float v = sin(centered.x * 10.0 + t);
    v += sin(centered.y * 10.0 + t * 1.2);
    v += sin((centered.x + centered.y) * 10.0 + t * 0.8);
    v += sin(length(centered) * 10.0 + t * 1.5);
    v *= 0.25;
    
    vec3 color = vec3(
        0.5 + 0.5 * sin(v * 3.14159 + t),
        0.5 + 0.5 * sin(v * 3.14159 + t + 2.0),
        0.5 + 0.5 * sin(v * 3.14159 + t + 4.0)
    );
    
    color *= intensity;
    return vec4(color, alpha);
}
```

## File Organization

- Metal shaders: `/shaders/*.metal` and `/shaders/effects/*.metal`
- GLSL shaders: `/shaders/*.frag` and `/shaders/effects/*.frag`
- Common library: `/shaders/base/common.glsl` and `/shaders/base/common.metal`

## Validation

Always validate GLSL shaders:
```bash
glslangValidator -V shaders/effects/your_shader.frag
```

## Notes

- Keep Metal shaders as the "source of truth" - update them first
- Maintain identical visual output between platforms
- Use the same mathematical constants and magic numbers
- Test on both macOS and Linux to ensure parity
