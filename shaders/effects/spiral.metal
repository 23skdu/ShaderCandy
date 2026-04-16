#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Spiral - rotating spiral pattern
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.5;
    
    // Polar coordinates
    float angle = atan2(uv.y, uv.x);
    float radius = length(uv);
    
    // Create spiral
    float spiral = angle / 3.14159 + log(radius + 0.1) * 3.0 - t;
    spiral = fract(spiral);
    
    // Add some variation
    float pattern = smoothstep(0.3, 0.7, spiral);
    
    // Color based on radius and angle
    float3 color = float3(
        0.5 + 0.5 * sin(radius * 5.0 + t),
        0.5 + 0.5 * sin(angle * 2.0 + t * 0.7),
        0.5 + 0.5 * sin(pattern * 6.28 + t * 1.2)
    );
    
    // Brighten the spiral arms
    color *= 0.5 + pattern * 0.5;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
