#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Audio waveform visualizer
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Get audio data
    float bass = uniforms.bass;
    float mid = uniforms.mid;
    float treble = uniforms.treble;
    float volume = uniforms.volume;
    
    // Background
    float3 color = float3(0.02, 0.02, 0.05);
    
    // Center line
    float lineY = 0.0;
    float line = smoothstep(0.01, 0.0, abs(p.y - lineY));
    color += float3(0.3, 0.4, 0.6) * line * 0.3;
    
    // Waveform - use bass, mid, treble for different frequencies
    float wave = 0.0;
    
    // Bass frequencies - big slow waves
    wave += sin(p.x * 5.0 + t * 2.0) * bass * 0.3;
    
    // Mid frequencies - medium waves
    wave += sin(p.x * 10.0 - t * 3.0 + p.y * 2.0) * mid * 0.2;
    
    // Treble - fast ripples
    wave += sin(p.x * 20.0 + t * 5.0) * treble * 0.1;
    
    // Draw waveform
    float waveDist = abs(p.y - wave);
    float waveLine = smoothstep(0.03, 0.0, waveDist);
    
    // Color based on frequency
    float3 waveColor = float3(
        0.2 + bass * 0.8,
        0.3 + mid * 0.7,
        0.5 + treble * 0.5
    );
    color += waveColor * waveLine;
    
    // Glow effect
    float glow = smoothstep(0.1, 0.0, waveDist);
    color += waveColor * glow * 0.3;
    
    // Frequency bars at bottom
    float barWidth = 0.04;
    float barSpacing = 0.05;
    float barY = -0.6;
    
    for (float i = -8.0; i <= 8.0; i++) {
        float barX = i * barSpacing;
        
        // Sample audio data (simplified)
        float freq = (i + 8.0) / 16.0;
        float barHeight = (bass * 0.5 + mid * 0.3 + treble * 0.2) * 
                          (0.5 + 0.5 * sin(freq * 20.0 + t * 5.0));
        barHeight *= 0.4;
        
        if (abs(p.x - barX) < barWidth * 0.5 && p.y > barY && p.y < barY + barHeight) {
            float3 barColor = hsv2rgb(float3(freq * 0.5 + t * 0.2, 0.9, 1.0));
            color = barColor;
        }
    }
    
    // Beat flash
    float beat = uniforms.beat;
    color += float3(0.5, 0.3, 0.8) * beat * 0.2;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
