// Audio Spectrum Visualization (Metal port)

#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 centered = in.texCoord * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time;
    float volume = uniforms.volume;
    float bass = uniforms.bass;
    float beat = uniforms.beat;
    float mid = uniforms.mid;
    float treble = uniforms.treble;
    
    float3 color = float3(0.0);
    
    // Background Grid
    float2 gridUV = centered * 5.0;
    float2 grid = abs(fract(gridUV) - 0.5);
    float lineDist = min(grid.x, grid.y);
    float line = smoothstep(0.02, 0.0, lineDist);
    float3 gridColor = hsv2rgb(float3(bass * 0.2 + t * 0.05, 0.7, 0.1 + volume * 0.3));
    color += gridColor * line * (1.0 - length(centered) * 0.2);
    
    // Circular Spectrum Bars
    float angle = atan2(centered.y, centered.x);
    float radius = length(centered);
    float normAngle = (angle / 3.14159 + 1.0) * 0.5; // 0 to 1
    
    // Extract spectrum data from audioData array
    // audioData is 256 floats, we'll use 64 bands for the circle
    int bandIdx = int(normAngle * 64.0) % 64;
    float bandValue = uniforms.audioData[bandIdx * 4]; // Sample every 4th value
    
    float innerR = 0.2 + bass * 0.1;
    float outerR = innerR + 0.05 + bandValue * 0.6;
    float barWidth = 0.008;
    float angleDist = abs(fract(normAngle * 64.0) - 0.5) * 2.0;
    float inBar = smoothstep(1.0 - barWidth * 100.0, 1.0, 1.0 - angleDist);
    float inRadius = smoothstep(innerR, innerR + 0.01, radius) * smoothstep(outerR + 0.01, outerR, radius);
    
    float3 barColor = hsv2rgb(float3(normAngle + t * 0.1, 0.8, 1.0));
    color += barColor * inBar * inRadius * (0.6 + volume);
    
    // Particles
    int numParticles = int(24.0 + volume * 50.0);
    if (numParticles > 64) numParticles = 64; // Cap for performance
    
    for (int i = 0; i < numParticles; i++) {
        float fi = float(i);
        float pAngle = fi * 1.5 + t * 0.3 + bass * 2.0;
        float pDist = 0.35 + fi * 0.02 + mid * 0.2 + beat * 0.15 * sin(fi * 2.0 + t * 4.0);
        float2 pPos = float2(cos(pAngle), sin(pAngle)) * pDist;
        float d = length(centered - pPos);
        float3 pCol = hsv2rgb(float3(fi / float(numParticles) + t * 0.05, 0.8, 1.0));
        float pGlow = exp(-d * 35.0) * (0.4 + volume * 0.8);
        color += pCol * pGlow;
    }
    
    // Center Glow / Beat reaction
    float centerGlow = exp(-radius * 8.0) * (bass * 0.5 + beat * 0.3);
    color += hsv2rgb(float3(t * 0.2, 0.6, 1.0)) * centerGlow;
    
    // Post-processing
    color *= 1.0 - length(centered) * 0.4; // Vignette
    color = color / (1.0 + color * 0.5); // Soft tone mapping
    
    // Apply globals
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
