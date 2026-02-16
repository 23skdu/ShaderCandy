#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Fireflies in a summer night
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.3;
    
    // Deep night sky
    float3 sky = float3(0.01, 0.02, 0.05);
    
    // Subtle stars
    float stars = pow(noise(p * 150.0), 25.0);
    sky += float3(0.8, 0.85, 1.0) * stars * 0.5;
    
    // Moon glow
    float2 moonPos = float2(0.7, 0.7);
    float moon = smoothstep(0.3, 0.0, length(p - moonPos));
    float moonGlow = smoothstep(0.8, 0.0, length(p - moonPos));
    sky += float3(0.9, 0.85, 0.7) * moon;
    sky += float3(0.6, 0.55, 0.4) * moonGlow * 0.2;
    
    // Ground
    float groundLevel = -0.5;
    float3 ground = float3(0.02, 0.04, 0.02);
    
    // Grass silhouettes
    for (float i = -3.0; i < 3.0; i += 0.08) {
        float grassX = i + sin(i * 15.0) * 0.02;
        float grassH = 0.05 + noise(float2(i * 50.0, 0.0)) * 0.08;
        
        if (abs(p.x - grassX) < 0.015 && p.y < groundLevel + grassH) {
            ground = float3(0.01, 0.03, 0.01);
        }
    }
    
    float3 color = sky;
    
    // Add ground to bottom
    if (p.y < groundLevel) {
        color = ground;
    }
    
    // Fireflies
    for (float i = 0.0; i < 25.0; i++) {
        float seed = i * 7.31;
        
        // Position with organic movement
        float2 ffPos = float2(
            sin(seed * 1.1 + t * (0.2 + hash(seed) * 0.3)) * 1.5,
            groundLevel + 0.1 + sin(seed * 2.3 + t * 0.5) * 0.3 + 
            cos(seed * 0.7 + t * 0.3) * 0.2
        );
        
        // Pulsing glow
        float pulse = sin(t * 3.0 + seed * 5.0) * 0.5 + 0.5;
        pulse = pow(pulse, 3.0);
        
        // Glow falloff
        float dist = length(p - ffPos);
        float glow = exp(-dist * 15.0) * pulse;
        
        // Firefly color (warm yellow-green)
        float3 ffColor = float3(0.9, 1.0, 0.4);
        
        color += ffColor * glow * 0.8;
    }
    
    // Ambient glow from fireflies
    color += float3(0.1, 0.15, 0.02) * 0.1;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
