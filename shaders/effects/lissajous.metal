#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Lissajous curves - mathematical beauty
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.5;
    
    // Lissajous parameters (animated)
    float a = 3.0 + sin(t * 0.3) * 0.5;
    float b = 2.0 + cos(t * 0.4) * 0.5;
    float delta = t * 0.5;
    
    // Draw multiple curves
    float3 color = float3(0.02, 0.03, 0.08);
    
    // Multiple lissajous curves
    for (float i = 0.0; i < 5.0; i++) {
        float offset = i * 0.2;
        float2 curvePos = float2(
            sin(a * t + offset + delta) * 0.7,
            sin(b * t + offset) * 0.7
        );
        
        // Distance to curve
        float dist = length(p - curvePos);
        float line = smoothstep(0.03, 0.0, dist);
        
        // Color variation
        float3 curveColor = hsv2rgb(float3(i * 0.2 + t * 0.1, 0.9, 1.0));
        color += curveColor * line;
    }
    
    // Trailing effect
    for (float i = 0.0; i < 30.0; i++) {
        float trailT = t - i * 0.05;
        float2 trailPos = float2(
            sin(a * trailT + delta) * 0.7,
            sin(b * trailT) * 0.7
        );
        
        float trailDist = length(p - trailPos);
        float trail = smoothstep(0.02, 0.0, trailDist);
        trail *= (1.0 - i / 30.0); // Fade out
        
        color += float3(0.3, 0.6, 1.0) * trail * 0.3;
    }
    
    // Grid background
    float2 grid = abs(fract(p * 10.0) - 0.5);
    float gridLine = smoothstep(0.48, 0.5, max(grid.x, grid.y));
    color += float3(0.1, 0.12, 0.15) * gridLine * 0.3;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
