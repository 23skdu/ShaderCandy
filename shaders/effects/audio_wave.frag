#version 450 core

#include "../base/common.glsl"

// Audio Waveform Visualization
// Renders the raw audio waveform as flowing lines

layout(std140) uniform AudioUniforms {
    float audioVolume;
    float audioBass;
    float audioMid;
    float audioTreble;
    float audioBeat;
    float audioBands[8];
    float audioSpectrum[64];
};

float hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec3 color = vec3(0.02, 0.02, 0.05);
    
    float volume = max(audioVolume, 0.05);
    float bass = max(audioBass, 0.0);
    
    float y = centered.y;
    float x = centered.x;
    
    float waveY = 0.0;
    float glow = 0.0;
    
    for (int i = 0; i < 64; i++) {
        float fi = float(i);
        float sample = audioSpectrum[i];
        
        float xPos = (fi / 32.0 - 1.0);
        float waveY1 = sample * 0.4 * sin(fi * 0.2 + t * 2.0);
        float waveY2 = sample * 0.2 * sin(fi * 0.3 + t * 3.0 + bass * 5.0);
        
        float dist = length(vec2(x - xPos, y - waveY1 - waveY2));
        float g = exp(-dist * 30.0) * sample;
        
        glow += g;
        
        if (dist < 0.03) {
            waveY = max(waveY, sample * (1.0 - dist * 30.0));
        }
    }
    
    vec3 waveColor = vec3(0.2, 0.8, 1.0);
    waveColor = mix(waveColor, vec3(1.0, 0.3, 0.5), bass);
    waveColor = mix(waveColor, vec3(0.3, 1.0, 0.5), volume * 0.5);
    
    color += waveColor * glow * 0.8;
    color += waveColor * waveY * 0.5;
    
    if (abs(x) < 0.02 && abs(y) < 0.3) {
        float lineDist = abs(y);
        float line = exp(-lineDist * 50.0);
        color += vec3(0.5, 0.5, 0.6) * line * 0.3;
    }
    
    color *= 1.0 - length(centered) * 0.2;
    color *= intensity;
    
    return vec4(color, alpha);
}