#version 450 core

#include "base/common.glsl"

// Audio Wave - Oscilloscope-style audio waveform

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = centered;
    float t = time * speed;
    
    // Audio simulation
    float bass = 0.5 + 0.5 * sin(t * 3.0);
    float mid = 0.5 + 0.5 * sin(t * 5.0 + 1.0);
    float treble = 0.5 + 0.5 * sin(t * 7.0 + 2.0);
    float beat = smoothstep(0.7, 1.0, bass);
    
    // Dark background
    vec3 color = vec3(0.01, 0.01, 0.02);
    
    // Grid
    vec2 grid = abs(fract(p * 4.0) - 0.5);
    float gridLine = smoothstep(0.48, 0.5, max(grid.x, grid.y));
    color += vec3(0.05) * gridLine;
    
    // Waveform parameters
    float waveY = 0.0;
    
    // Combine multiple sine waves for audio-like appearance
    waveY += bass * 0.3 * sin(p.x * 10.0 + t * 5.0);
    waveY += mid * 0.2 * sin(p.x * 20.0 + t * 8.0);
    waveY += treble * 0.1 * sin(p.x * 40.0 + t * 12.0);
    
    // Add some harmonics
    waveY += bass * 0.15 * sin(p.x * 30.0 + t * 6.0);
    waveY += mid * 0.1 * sin(p.x * 50.0 + t * 10.0);
    
    // Draw waveform
    float wave = smoothstep(0.05, 0.0, abs(p.y - waveY));
    
    // Color based on amplitude
    vec3 waveColor = hsv2rgb(vec3(
        0.3 + beat * 0.2,
        0.9,
        0.8 + beat * 0.2
    ));
    
    color = mix(color, waveColor, wave);
    
    // Glow around wave
    float glow = smoothstep(0.15, 0.0, abs(p.y - waveY));
    color += vec3(0.2, 0.5, 0.8) * glow * 0.3;
    
    // Center line
    float centerLine = smoothstep(0.01, 0.0, abs(p.y));
    color += vec3(0.1, 0.1, 0.15) * centerLine;
    
    // Beat flash
    color += vec3(0.1, 0.05, 0.15) * beat * 0.3;
    
    color *= intensity;
    return vec4(color, alpha);
}
