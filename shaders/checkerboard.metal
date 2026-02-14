#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Checkerboard - animated checkerboard with color cycling
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 20.0; // Scale up for more squares
    float t = uniforms.time * uniforms.speed * 0.3;
    
    // Create checkerboard pattern
    float2 grid = floor(uv);
    float checker = fmod(grid.x + grid.y, 2.0);
    
    // Animate the colors
    float3 color1 = float3(
        0.5 + 0.5 * sin(t),
        0.5 + 0.5 * sin(t + 2.0),
        0.5 + 0.5 * sin(t + 4.0)
    );
    
    float3 color2 = float3(
        0.5 + 0.5 * sin(t + 3.0),
        0.5 + 0.5 * sin(t + 5.0),
        0.5 + 0.5 * sin(t + 1.0)
    );
    
    // Mix colors based on checker pattern
    float3 color = mix(color1, color2, checker);
    
    // Add some shimmer
    float shimmer = sin(grid.x * 0.5 + grid.y * 0.5 + t * 2.0) * 0.1 + 0.9;
    color *= shimmer;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
