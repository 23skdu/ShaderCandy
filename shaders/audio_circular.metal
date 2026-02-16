#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Circular audio visualizer
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Audio data
    float bass = uniforms.bass;
    float mid = uniforms.mid;
    float treble = uniforms.treble;
    float beat = uniforms.beat;
    
    // Polar coordinates
    float r = length(p);
    float angle = atan2(p.y, p.x);
    
    // Center
    float3 color = float3(0.02, 0.02, 0.05);
    
    // Base circle
    float baseRadius = 0.3;
    float circleLine = smoothstep(0.02, 0.0, abs(r - baseRadius));
    color += float3(0.2, 0.3, 0.5) * circleLine;
    
    // Frequency bars in a circle
    int numBars = 48;
    float barAngle = 6.28318 / float(numBars);
    
    for (int i = 0; i < 48; i++) {
        float a = float(i) * barAngle + t * 0.2;
        
        // Frequency for this bar (bass inner, treble outer)
        float freq = float(i) / float(numBars);
        float barHeight = mix(bass, treble, freq) * 0.5;
        barHeight *= 0.7 + 0.3 * sin(float(i) * 2.0 + t * 4.0);
        
        // Bar direction
        float2 dir = float2(cos(a), sin(a));
        float2 barPos = dir * baseRadius;
        
        // Distance to bar line
        float2 toPoint = p - barPos;
        float alongBar = dot(toPoint, dir);
        float perpBar = length(toPoint - dir * alongBar);
        
        if (alongBar > 0.0 && alongBar < barHeight && perpBar < 0.02) {
            float3 barColor = hsv2rgb(float3(freq * 0.5 + t * 0.1, 0.9, 1.0));
            color = barColor;
        }
    }
    
    // Inner circle pulse with beat
    float pulseRadius = baseRadius * (0.8 + beat * 0.2);
    float pulse = smoothstep(0.03, 0.0, abs(r - pulseRadius));
    color += float3(0.5, 0.2, 0.8) * pulse * beat;
    
    // Center glow
    float centerGlow = smoothstep(0.3, 0.0, r);
    color += float3(0.1, 0.15, 0.3) * centerGlow;
    
    // Orbiting particles
    for (float i = 0.0; i < 8.0; i++) {
        float orbitAngle = t * (0.5 + i * 0.1) + i * 0.8;
        float orbitR = 0.15 + bass * 0.1;
        float2 orbitPos = float2(cos(orbitAngle), sin(orbitAngle)) * orbitR;
        
        float particle = smoothstep(0.03, 0.0, length(p - orbitPos));
        float3 particleColor = hsv2rgb(float3(i * 0.1 + t * 0.2, 0.8, 1.0));
        color += particleColor * particle;
    }
    
    // Background particles
    float bgParticles = pow(noise(p * 50.0 + t), 20.0);
    color += float3(0.5, 0.6, 0.8) * bgParticles * 0.3;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
