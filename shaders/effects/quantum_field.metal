#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Quantum Field - Wave function visualization

// Schrodinger-inspired wave equation
float waveFunction(float2 pos, float t, float n, float m) {
    float x = pos.x * PI * n;
    float y = pos.y * PI * m;
    
    float phase = t * 2.0 + n * m;
    
    float psi = sin(x + phase) * sin(y + phase * 0.7);
    psi += 0.5 * sin(x * 2.0 - phase) * sin(y * 2.0 + phase * 0.5);
    
    return psi;
}

// Probability density
float probabilityDensity(float2 pos, float t) {
    float psi = waveFunction(pos, t, 3.0, 2.0);
    return psi * psi;
}

// Interference pattern
float interference(float2 uv, float t) {
    float intensity = 0.0;
    
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 source = float2(
            cos(fi * 1.5 + t * 0.3) * 0.4,
            sin(fi * 1.2 + t * 0.2) * 0.4
        );
        
        float dist = length(uv - source);
        float wave = sin(dist * 20.0 - t * 3.0) * exp(-dist * 2.0);
        intensity += wave;
    }
    
    return intensity;
}

// Quantum tunneling
float quantumTunneling(float2 uv, float t) {
    float barrier = smoothstep(0.05, 0.0, abs(uv.x));
    
    float packet = exp(-pow(uv.x + 0.5 + t * 0.1, 2.0) * 20.0);
    
    float tunneling = exp(-abs(uv.x) * 5.0) * (1.0 - barrier);
    
    float reflected = packet * barrier;
    float transmitted = packet * tunneling * 0.3;
    
    return reflected + transmitted;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float2 pos = uv * 2.0 - 1.0;
    float t = uniforms.time * uniforms.speed;
    
    float3 col = float3(0.0);
    
    float prob = probabilityDensity(pos, t);
    float3 probColor = hsv2rgb(float3(
        prob * 0.3 + t * 0.05,
        0.8,
        prob * 0.8
    ));
    col += probColor;
    
    float interfere = interference(pos, t);
    col += float3(0.2, 0.5, 1.0) * interfere * 0.3;
    
    float tunnel = quantumTunneling(pos, t);
    col += float3(0.8, 0.3, 0.9) * tunnel * 0.5;
    
    for (int i = 0; i < 20; i++) {
        float fi = float(i);
        float angle = fi * 0.5 + t * (0.5 + fi * 0.05);
        float radius = 0.3 + sin(t * 2.0 + fi) * 0.1;
        
        float2 particle = float2(cos(angle), sin(angle)) * radius;
        float d = length(pos - particle);
        
        float wave = exp(-d * d * 50.0) * sin(d * 30.0 - t * 5.0);
        float particleSpot = exp(-d * d * 200.0);
        
        float dual = mix(wave, particleSpot, 0.5 + 0.5 * sin(t + fi));
        
        col += hsv2rgb(float3(fi / 20.0, 0.9, 1.0)) * dual * 0.1;
    }
    
    float entanglement = sin(pos.x * 10.0 + t) * sin(pos.y * 10.0 + t);
    col += float3(1.0, 0.0, 0.5) * entanglement * 0.1;
    
    float glow = smoothstep(0.5, 1.0, prob);
    col += float3(0.5, 0.8, 1.0) * glow * 0.3;
    
    col *= 1.0 - length(centered) * 0.4;
    col = col / (1.0 + col * 0.5);
    
    return float4(col * uniforms.intensity, uniforms.alpha);
}
