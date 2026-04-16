#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Ripples - concentric waves emanating from center
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Distance from center
    float dist = length(uv);
    
    // Create ripple effect
    float ripple = sin(dist * 20.0 - t * 3.0) * 0.5 + 0.5;
    ripple *= 1.0 / (1.0 + dist * 2.0); // Fade with distance
    
    // Add secondary ripples
    float ripple2 = sin(dist * 15.0 - t * 2.0 + 1.0) * 0.5 + 0.5;
    ripple2 *= 1.0 / (1.0 + dist * 3.0);
    
    // Combine ripples
    float combined = ripple + ripple2 * 0.5;
    
    // Color based on ripple intensity
    float3 color = float3(
        0.2 + combined * 0.8,
        0.4 + combined * 0.6 * sin(t * 0.5),
        0.6 + combined * 0.4 * cos(t * 0.3)
    );
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
