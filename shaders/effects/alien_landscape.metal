#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Alien landscape - strange terrain
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.15;
    
    // Alien sky - purple/teal gradient
    float3 skyTop = float3(0.05, 0.0, 0.15);
    float3 skyBottom = float3(0.1, 0.2, 0.25);
    float3 color = mix(skyBottom, skyTop, uv.y);
    
    // Two moons
    float2 moon1Pos = float2(-0.6, 0.7);
    float2 moon2Pos = float2(0.5, 0.6);
    
    float moon1 = smoothstep(0.08, 0.0, length(p - moon1Pos));
    float moon1Glow = smoothstep(0.3, 0.0, length(p - moon1Pos));
    
    float moon2 = smoothstep(0.05, 0.0, length(p - moon2Pos));
    float moon2Glow = smoothstep(0.2, 0.0, length(p - moon2Pos));
    
    color += float3(0.8, 0.85, 1.0) * moon1;
    color += float3(0.9, 0.7, 0.6) * moon2;
    color += float3(0.3, 0.35, 0.5) * moon1Glow * 0.2;
    color += float3(0.4, 0.3, 0.25) * moon2Glow * 0.15;
    
    // Strange alien terrain using SDF
    float terrain = -0.5;
    terrain += sin(p.x * 3.0 + 1.0) * 0.2;
    terrain += sin(p.x * 7.0) * 0.08;
    terrain += noise(p * 3.0) * 0.15;
    
    // Alien rock formations
    for (float i = -2.0; i < 2.0; i += 0.4) {
        float rockX = i + sin(i * 5.0) * 0.2;
        float rockH = 0.15 + noise(float2(i * 10.0, 0.0)) * 0.25;
        float rockW = 0.05 + noise(float2(i * 15.0, 1.0)) * 0.05;
        
        // Spiky alien rocks
        float rockShape = max(0.0, rockW - abs(p.x - rockX));
        rockShape = max(rockShape, (rockH - max(0.0, p.y - terrain)) * 0.5);
        
        if (p.y < terrain + rockH && abs(p.x - rockX) < rockW * 2.0) {
            float shade = (p.y - terrain) / rockH;
            color = mix(float3(0.15, 0.1, 0.2), float3(0.3, 0.2, 0.35), shade);
            
            // Glow from crystals
            if (noise(float2(i * 20.0, p.y * 10.0)) > 0.7 && p.y > terrain + rockH * 0.6) {
                color += float3(0.2, 0.8, 0.6) * 0.3;
            }
        }
    }
    
    // Ground
    if (p.y < terrain) {
        float3 groundColor = float3(0.08, 0.12, 0.15);
        float groundNoise = noise(p * 20.0);
        color = mix(groundColor, float3(0.12, 0.18, 0.2), groundNoise * 0.5);
    }
    
    // Glowing alien plants
    for (float i = 0.0; i < 15.0; i++) {
        float seed = i * 2.71;
        float2 plantPos = float2(
            hash(seed) * 2.0 - 1.0,
            terrain + hash(seed + 100.0) * 0.1
        );
        
        // Bioluminescent tendrils
        float tendril = sin(p.x * 30.0 + seed + t) * exp(-abs(p.y - plantPos.y) * 20.0);
        tendril *= smoothstep(0.3, 0.0, abs(p.x - plantPos.x));
        
        float3 plantColor = hsv2rgb(float3(hash(seed + 200.0), 0.8, 1.0));
        color += plantColor * tendril * 0.3;
    }
    
    // Atmospheric fog
    float fog = smoothstep(0.3, -0.5, p.y);
    color = mix(color, skyBottom * 0.5, fog * 0.4);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
