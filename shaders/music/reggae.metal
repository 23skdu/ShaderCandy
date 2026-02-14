// Reggae 3D - Tropical Flag
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    // Wave effect for the flag
    float wave = sin(uv.x * 4.0 - t * 3.0) * 0.1 * (uv.x + 0.1);
    float waveY = sin(uv.y * 2.0 - t * 2.0) * 0.05;
    float2 wuv = uv + float2(0.0, wave + waveY);
    
    float3 color = float3(0.0, 0.2, 0.4); // Deep blue ocean background
    
    // Sun
    float sun = smoothstep(0.4, 0.38, length(p - float2(0.8, 0.6)));
    color = mix(color, float3(1.0, 0.9, 0.2), sun);
    
    // Flag area
    if(wuv.y > 0.2 && wuv.y < 0.8 && wuv.x > 0.1 && wuv.x < 0.9) {
        // Red, Gold, Green stripes
        float3 rgg;
        if(wuv.y > 0.6) rgg = float3(0.8, 0.1, 0.1); // Red
        else if(wuv.y > 0.4) rgg = float3(1.0, 0.8, 0.0); // Gold
        else rgg = float3(0.1, 0.6, 0.1); // Green
        
        // Add shading based on waves
        float shading = 1.0 + (wave + waveY) * 5.0;
        color = rgg * shading;
        
        // Add fabric texture
        float tex = custom_noise(wuv * 200.0);
        color *= (0.9 + 0.1 * tex);
    }
    
    // Palms (silhouette)
    float palm = 0.0;
    float2 pp = p - float2(-0.8, -1.0);
    float ang = atan2(pp.y, pp.x);
    float rad = length(pp);
    float leaf = sin(ang * 10.0) * 0.2 + 0.5;
    if(rad < leaf && pp.y > 0.0) palm = 1.0;
    color = mix(color, float3(0.02, 0.05, 0.02), palm * smoothstep(1.5, 0.0, rad));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
