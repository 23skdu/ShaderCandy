#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Trigonometric patterns - mesmerizing geometry
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Multiple trig patterns
    float pattern = 0.0;
    
    // Wave pattern 1
    pattern += sin(p.x * 10.0 + t) * cos(p.y * 8.0 - t * 0.7);
    
    // Wave pattern 2
    pattern += sin(p.x * 15.0 - t * 1.3) * sin(p.y * 12.0 + t);
    
    // Circular ripples
    float r = length(p);
    pattern += sin(r * 20.0 - t * 2.0) * 0.5;
    
    // Angular patterns
    float angle = atan2(p.y, p.x);
    pattern += sin(angle * 8.0 + t) * 0.5;
    
    pattern = pattern * 0.25 + 0.5;
    
    // Color mapping with multiple palettes
    float3 color1 = float3(0.1, 0.4, 0.8);
    float3 color2 = float3(0.8, 0.2, 0.5);
    float3 color3 = float3(0.2, 0.8, 0.6);
    
    float3 color = mix(color1, color2, sin(pattern * 3.14159 + t) * 0.5 + 0.5);
    color = mix(color, color3, cos(pattern * 6.28 - t * 0.7) * 0.5 + 0.5);
    
    // Add some sparkle
    float sparkle = pow(noise(p * 50.0 + t), 15.0);
    color += float3(1.0) * sparkle;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
