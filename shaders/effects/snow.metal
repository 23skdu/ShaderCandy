#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Snowfall
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Winter night sky
    float3 color = float3(0.05, 0.08, 0.15);
    
    // Moon
    float2 moonPos = float2(0.6, 0.65);
    float moon = smoothstep(0.12, 0.0, length(p - moonPos));
    float moonGlow = smoothstep(0.5, 0.0, length(p - moonPos));
    color += float3(0.9, 0.92, 1.0) * moon;
    color += float3(0.4, 0.45, 0.5) * moonGlow * 0.15;
    
    // Distant mountains
    float mountainLine = -0.4 + sin(p.x * 2.0) * 0.15 + sin(p.x * 5.0) * 0.05;
    if (p.y < mountainLine + 0.1) {
        color = float3(0.15, 0.18, 0.25);
    }
    
    // Snow-covered ground
    if (p.y < -0.55) {
        color = float3(0.9, 0.92, 0.95);
        
        // Snow texture
        float snowNoise = noise(p * 30.0) * 0.1;
        color -= snowNoise;
    }
    
    // Snowflakes
    float snow = 0.0;
    for (float i = 0.0; i < 100.0; i++) {
        float seed = i * 0.23;
        
        // Falling motion with drift
        float drift = sin(seed * 3.0 + t * 0.5) * 0.3;
        float fallSpeed = 0.3 + hash(seed) * 0.4;
        
        float2 snowPos = float2(
            hash(seed) * 2.5 - 1.25 + drift,
            mod(hash(seed + 100.0) + t * fallSpeed, 2.2) - 1.1
        );
        
        // Size variation
        float size = 0.005 + hash(seed + 200.0) * 0.01;
        
        float flake = smoothstep(size, 0.0, length(p - snowPos));
        
        // Blur for depth
        flake *= 0.5 + hash(seed + 300.0) * 0.5;
        
        snow += flake * 0.4;
    }
    
    // Add snow glow
    color += float3(1.0) * snow;
    
    // Snow mounds on ground
    for (float i = -3.0; i < 3.0; i += 0.3) {
        float moundX = i + sin(i * 7.0) * 0.15;
        float moundH = 0.03 + noise(float2(i * 10.0, 0.0)) * 0.04;
        
        if (p.y < -0.55 + moundH && abs(p.x - moundX) < 0.2) {
            float mound = smoothstep(-0.55, -0.55 + moundH, p.y);
            float sideFade = smoothstep(0.2, 0.0, abs(p.x - moundX));
            color = mix(color, float3(0.95, 0.97, 1.0), mound * sideFade);
        }
    }
    
    // Subtle blue tint to shadows
    color = mix(color, float3(0.7, 0.8, 0.95), (1.0 - color) * 0.1);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
