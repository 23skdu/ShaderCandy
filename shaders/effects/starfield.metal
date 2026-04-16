#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Starfield with parallax
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.15;
    
    // Deep space
    float3 color = float3(0.01, 0.01, 0.02);
    
    // Multiple star layers with parallax
    for (float layer = 0.0; layer < 4.0; layer++) {
        float speed = 0.2 + layer * 0.15;
        float scale = 100.0 + layer * 50.0;
        float brightness = 1.0 - layer * 0.2;
        
        // Stars at this layer
        float stars = pow(noise(p * scale + float2(t * speed, 0.0)), 30.0 - layer * 5.0);
        
        // Twinkle
        float twinkle = sin(t * (3.0 + layer) + p.x * 50.0 + p.y * 30.0) * 0.4 + 0.6;
        stars *= twinkle;
        
        color += float3(brightness) * stars;
    }
    
    // Bright stars with glow
    float brightStars = pow(noise(p * 80.0 + float2(t * 0.1, 0.0)), 35.0);
    if (brightStars > 0.5) {
        float glow = smoothstep(0.5, 1.0, brightStars);
        color += float3(1.0, 0.95, 0.9) * glow;
        
        // Color variation for some stars
        float colorVar = noise(p * 50.0);
        if (colorVar > 0.7) {
            color += float3(0.3, 0.5, 1.0) * glow * 0.5; // Blue star
        } else if (colorVar > 0.5) {
            color += float3(1.0, 0.7, 0.4) * glow * 0.5; // Orange star
        }
    }
    
    // Distant nebula glow
    float nebula = fbm(float3(p * 2.0, t * 0.05), 3) * 0.15;
    color += float3(0.3, 0.2, 0.4) * nebula;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
