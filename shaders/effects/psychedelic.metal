#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Psychedelic swirl
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Polar coordinates
    float r = length(p);
    float angle = atan2(p.y, p.x);
    
    // Multiple rotating spiral patterns
    float spiral1 = sin(angle * 8.0 - r * 15.0 + t * 2.0);
    float spiral2 = sin(angle * 12.0 + r * 10.0 - t * 1.5);
    float spiral3 = sin(angle * 6.0 - r * 8.0 + t * 3.0);
    
    // Combine spirals
    float pattern = spiral1 * 0.5 + spiral2 * 0.3 + spiral3 * 0.2;
    pattern = pattern * 0.5 + 0.5;
    
    // Color cycling through rainbow
    float hue = pattern + t * 0.2 + r * 0.5;
    float3 color = hsv2rgb(float3(hue, 0.9, 0.9));
    
    // Add more vibrant colors
    float hue2 = pattern * 2.0 + t * 0.3;
    float3 color2 = hsv2rgb(float3(hue2, 0.8, 1.0));
    
    color = mix(color, color2, sin(pattern * 6.28 + t) * 0.5 + 0.5);
    
    // Inner glow
    float glow = smoothstep(1.0, 0.0, r);
    color += float3(0.3, 0.2, 0.5) * glow;
    
    // Kaleidoscope effect
    float kaleido = mod(angle * 3.0 + t, 6.28318);
    kaleido = abs(kaleido - 3.14159);
    float kaleidoMask = smoothstep(0.5, 0.0, kaleido);
    
    color = mix(color, float3(1.0) - color, kaleidoMask * 0.3);
    
    // Pulsing center
    float pulse = sin(t * 3.0) * 0.5 + 0.5;
    float center = smoothstep(0.3, 0.0, r);
    color += float3(1.0, 0.5, 0.8) * center * pulse * 0.4;
    
    // Vignette
    color *= 1.0 - r * 0.4;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
