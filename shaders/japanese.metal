#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Japanese art - Cherry blossoms and waves
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.2;
    
    // Traditional Japanese color palette
    float3 skyColor = float3(0.95, 0.9, 0.85); // Cream white
    float3 inkColor = float3(0.1, 0.1, 0.15);  // Sumi ink
    
    float3 color = skyColor;
    
    // Mt. Fuji silhouette
    float mountainY = -0.3;
    float mountain = mountainY + sin(p.x * 3.0) * 0.15 + 0.3;
    
    if (p.y < mountain && p.y > mountain - 0.5) {
        color = mix(inkColor, skyColor, smoothstep(mountain - 0.02, mountain + 0.02, p.y));
    }
    
    // Snow cap
    float snowCap = mountainY + sin(p.x * 3.0) * 0.15 + 0.35;
    if (p.y < snowCap && p.y > mountain && abs(p.x) < 0.15) {
        color = float3(0.95);
    }
    
    // Wave pattern (traditional seigaiha)
    float waveY = -0.5;
    float waveRadius = 0.1;
    float waveSpacing = 0.15;
    
    float2 waveCenter = float2(0.0, waveY);
    for (float i = 0.0; i < 3.0; i++) {
        waveCenter.y = waveY - i * waveSpacing;
        float wave = smoothstep(waveRadius + 0.01, waveRadius, length(p - waveCenter));
        waveCenter.x += waveSpacing;
        float wave2 = smoothstep(waveRadius + 0.01, waveRadius, length(p - waveCenter));
        waveCenter.x -= waveSpacing * 2.0;
        float wave3 = smoothstep(waveRadius + 0.01, waveRadius, length(p - waveCenter));
        
        color = mix(color, inkColor, (wave + wave2 + wave3) * 0.3 * (1.0 - i * 0.3));
    }
    
    // Falling cherry blossoms
    for (float i = 0.0; i < 20.0; i++) {
        float seed = i * 1.23;
        float fallSpeed = 0.2 + hash(seed) * 0.3;
        float2 petalPos = float2(
            hash(seed + 50.0) * 2.0 - 1.0 + sin(t + seed) * 0.2,
            mod(hash(seed + 100.0) + t * fallSpeed, 2.2) - 1.1
        );
        
        float petal = smoothstep(0.02, 0.0, length(p - petalPos));
        
        // Pink sakura color
        float3 petalColor = float3(1.0, 0.7, 0.8);
        color += petalColor * petal * 0.8;
    }
    
    // Branch silhouette
    float branchY = 0.4;
    if (p.y < branchY && p.y > branchY - 0.3 && abs(p.x) < 0.1 + p.y * 0.5) {
        color = mix(color, inkColor, 0.7);
    }
    
    // Sun (traditional red circle)
    float2 sunPos = float2(0.5, 0.5);
    float sun = smoothstep(0.15, 0.0, length(p - sunPos));
    color = mix(color, float3(0.9, 0.2, 0.2), sun);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
