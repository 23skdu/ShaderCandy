#version 450 core

#include "../base/common.glsl"

// Audio-reactive spectrum visualization
// Responds to music with flowing particle bars

// Audio uniforms (when audio input is available)
layout(std140) uniform AudioUniforms {
    float audioVolume;
    float audioBass;
    float audioMid;
    float audioTreble;
    float audioBeat;
    float audioBands[8];
    float audioSpectrum[64];  // Reduced spectrum for performance
};

// Smooth step function
float smoothStep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// Circular bar visualization
float circularBars(vec2 uv, float t) {
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);
    
    // Map angle to audio band
    float normalizedAngle = (angle / PI + 1.0) * 0.5; // 0 to 1
    int bandIndex = int(normalizedAngle * 8.0) % 8;
    float bandValue = audioBands[bandIndex];
    
    // Create bar
    float barWidth = 0.02;
    float barHeight = 0.3 + bandValue * 0.4;
    
    // Inner and outer radius based on audio
    float innerR = 0.15 + audioBass * 0.1;
    float outerR = innerR + barHeight;
    
    // Check if we're in the bar region
    float angleDist = abs(fract(normalizedAngle * 8.0) - 0.5) * 2.0;
    float inBar = smoothStep(1.0 - barWidth * 8.0, 1.0, 1.0 - angleDist);
    float inRadius = smoothStep(innerR, innerR + 0.01, radius) * 
                     smoothStep(outerR + 0.01, outerR, radius);
    
    return inBar * inRadius;
}

// Particle system responding to audio
vec3 audioParticles(vec2 uv, float t) {
    vec3 color = vec3(0.0);
    
    // Number of particles based on volume
    int numParticles = int(20.0 + audioVolume * 30.0);
    
    for (int i = 0; i < numParticles; i++) {
        float fi = float(i);
        
        // Particle position based on audio
        float angle = fi * 0.5 + t * 0.1 + audioBass * 2.0;
        float dist = 0.2 + fi * 0.02 + audioMid * 0.2;
        
        // Add beat reaction
        dist += audioBeat * 0.1 * sin(fi * 3.0 + t * 5.0);
        
        vec2 particlePos = vec2(
            cos(angle) * dist,
            sin(angle) * dist
        );
        
        // Particle size responds to treble
        float particleSize = 0.01 + audioTreble * 0.02;
        
        // Distance to particle
        float d = length(uv - particlePos);
        
        // Color based on frequency
        vec3 particleColor = hsv2rgb(vec3(
            fi / float(numParticles) + audioBass * 0.2,
            0.8,
            1.0
        ));
        
        // Add glow
        float glow = exp(-d * 50.0) * (0.5 + audioVolume * 0.5);
        color += particleColor * glow;
    }
    
    return color;
}

// Waveform visualization
float waveform(vec2 uv, float t) {
    float wave = 0.0;
    
    // Create waveform from spectrum data
    for (int i = 0; i < 32; i++) {
        float fi = float(i);
        float freq = fi / 32.0;
        float amp = audioSpectrum[i * 2];
        
        // Position on screen
        float x = (fi / 16.0 - 1.0) * 2.0;
        float y = sin(freq * 10.0 + t * 2.0) * amp * 0.3;
        
        // Distance to wave point
        float d = length(uv - vec2(x, y));
        wave += exp(-d * 100.0) * amp;
    }
    
    return wave;
}

// Background reative grid
vec3 reactiveGrid(vec2 uv, float t) {
    vec3 color = vec3(0.0);
    
    // Grid lines
    vec2 grid = abs(fract(uv * 10.0) - 0.5);
    float line = smoothStep(0.02, 0.0, min(grid.x, grid.y));
    
    // Audio-reactive intensity
    float intensity = 0.1 + audioVolume * 0.3;
    
    // Beat flash
    intensity += audioBeat * 0.5 * exp(-mod(t, 0.5) * 10.0);
    
    // Color based on bass
    vec3 gridColor = hsv2rgb(vec3(
        audioBass * 0.2 + t * 0.05,
        0.7,
        intensity
    ));
    
    color += gridColor * line;
    
    return color;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    // Fallback if no audio
    float volume = max(audioVolume, 0.1);
    float bass = max(audioBass, 0.1);
    float beat = max(audioBeat, 0.0);
    
    vec3 color = vec3(0.0);
    
    // Background
    color += reactiveGrid(centered * 0.5, time) * 0.5;
    
    // Circular spectrum bars
    float bars = circularBars(centered, time);
    vec3 barColor = hsv2rgb(vec3(
        bass * 0.3 + time * 0.1,
        0.8,
        1.0
    ));
    color += barColor * bars * (0.5 + volume);
    
    // Particles
    color += audioParticles(centered, time);
    
    // Waveform overlay
    float wave = waveform(centered, time);
    color += vec3(1.0, 0.8, 0.5) * wave * (0.3 + beat * 0.5);
    
    // Beat flash effect
    if (beat > 0.5) {
        color += vec3(1.0) * beat * 0.1 * exp(-mod(time * 2.0, 1.0) * 5.0);
    }
    
    // Vignette
    color *= 1.0 - length(centered) * 0.3;
    
    // Tone mapping
    color = color / (1.0 + color);
    
    return vec4(color, 1.0);
}
