#version 450 core

#include "../base/common.glsl"

// Audio Bars Visualization
// Classic equalizer bars

layout(std140) uniform AudioUniforms {
    float audioVolume;
    float audioBass;
    float audioMid;
    float audioTreble;
    float audioBeat;
    float audioBands[8];
    float audioSpectrum[64];
};

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec3 color = vec3(0.01, 0.01, 0.02);
    
    float volume = max(audioVolume, 0.1);
    float bass = max(audioBass, 0.0);
    float mid = max(audioMid, 0.0);
    float treble = max(audioTreble, 0.0);
    
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        
        float x = (fi / 8.0 - 1.0);
        float barHeight = 0.0;
        
        if (i < 8) {
            barHeight = audioBands[i] * 0.5;
        } else {
            barHeight = audioSpectrum[i * 4] * 0.5;
        }
        
        barHeight += 0.05;
        
        float barWidth = 0.08;
        float distX = abs(centered.x - x);
        float distY = centered.y - (-0.3 + barHeight * 0.5);
        
        if (distX < barWidth && centered.y > -0.3 && centered.y < -0.3 + barHeight) {
            float hue = fi / 16.0 + t * 0.1;
            vec3 barColor = vec3(
                0.5 + 0.5 * sin(hue * 6.28),
                0.5 + 0.5 * sin(hue * 6.28 + 2.09),
                0.5 + 0.5 * sin(hue * 6.28 + 4.18)
            );
            color += barColor * (0.5 + volume * 0.5);
        }
        
        float glowX = abs(centered.x - x);
        float glowY = abs(centered.y - (-0.3 + barHeight * 0.5));
        float glow = exp(-(glowX * 20.0 + glowY * 5.0)) * barHeight;
        color += vec3(0.2, 0.5, 1.0) * glow * 0.3;
    }
    
    color *= 1.0 - length(centered) * 0.2;
    color *= intensity;
    
    return vec4(color, alpha);
}