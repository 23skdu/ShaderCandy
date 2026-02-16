#version 450 core

#include "../base/common.glsl"

// Quantum Field - Wave function visualization
// Visualizing probability waves and interference patterns

// Schrodinger-inspired wave equation
float waveFunction(vec2 pos, float t, float n, float m) {
    // Standing wave pattern
    float x = pos.x * PI * n;
    float y = pos.y * PI * m;
    
    // Time evolution with phase
    float phase = t * 2.0 + n * m;
    
    // Wave superposition
    float psi = sin(x + phase) * sin(y + phase * 0.7);
    psi += 0.5 * sin(x * 2.0 - phase) * sin(y * 2.0 + phase * 0.5);
    
    return psi;
}

// Probability density (|psi|^2)
float probabilityDensity(vec2 pos, float t) {
    float psi = waveFunction(pos, t, 3.0, 2.0);
    return psi * psi;
}

// Interference pattern from multiple sources
float interference(vec2 uv, float t) {
    float intensity = 0.0;
    
    // Multiple wave sources
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 source = vec2(
            cos(fi * 1.5 + t * 0.3) * 0.4,
            sin(fi * 1.2 + t * 0.2) * 0.4
        );
        
        float dist = length(uv - source);
        float wave = sin(dist * 20.0 - t * 3.0) * exp(-dist * 2.0);
        intensity += wave;
    }
    
    return intensity;
}

// Uncertainty visualization
vec3 uncertaintyPrinciple(vec2 uv, float t) {
    vec3 color = vec3(0.0);
    
    // Position uncertainty (sharp peak)
    float position = exp(-length(uv) * 10.0) * 2.0;
    
    // Momentum uncertainty (spread out)
    float momentum = 0.0;
    for (float i = 0.0; i < 10.0; i++) {
        momentum += sin(dot(uv, vec2(cos(i), sin(i))) * 10.0 + t) * 0.1;
    }
    
    // Heisenberg: sharp position = spread momentum
    color.r = position;
    color.b = momentum * 0.5 + 0.5;
    color.g = (1.0 - position) * (momentum * 0.5 + 0.5);
    
    return color;
}

// Tunneling effect
float quantumTunneling(vec2 uv, float t) {
    // Potential barrier
    float barrier = smoothstep(0.05, 0.0, abs(uv.x));
    
    // Wave packet approaching barrier
    float packet = exp(-pow(uv.x + 0.5 + t * 0.1, 2.0) * 20.0);
    
    // Tunneling probability (exponential decay through barrier)
    float tunneling = exp(-abs(uv.x) * 5.0) * (1.0 - barrier);
    
    // Reflected and transmitted waves
    float reflected = packet * barrier;
    float transmitted = packet * tunneling * 0.3;
    
    return reflected + transmitted;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    // Normalize to -1 to 1
    vec2 pos = uv * 2.0 - 1.0;
    
    vec3 color = vec3(0.0);
    
    // Quantum probability field
    float prob = probabilityDensity(pos, time);
    vec3 probColor = hsv2rgb(vec3(
        prob * 0.3 + time * 0.05,
        0.8,
        prob * 0.8
    ));
    color += probColor;
    
    // Interference pattern
    float interfere = interference(pos, time);
    color += vec3(0.2, 0.5, 1.0) * interfere * 0.3;
    
    // Uncertainty visualization (subtle overlay)
    vec3 uncertainty = uncertaintyPrinciple(pos, time);
    color = mix(color, uncertainty, 0.2);
    
    // Quantum tunneling visualization
    float tunnel = quantumTunneling(pos, time);
    color += vec3(0.8, 0.3, 0.9) * tunnel * 0.5;
    
    // Particle wave duality (dots that trace wave paths)
    for (int i = 0; i < 20; i++) {
        float fi = float(i);
        float angle = fi * 0.5 + time * (0.5 + fi * 0.05);
        float radius = 0.3 + sin(time * 2.0 + fi) * 0.1;
        
        vec2 particle = vec2(cos(angle), sin(angle)) * radius;
        float d = length(pos - particle);
        
        // Wave nature (spread out)
        float wave = exp(-d * d * 50.0) * sin(d * 30.0 - time * 5.0);
        
        // Particle nature (localized)
        float particleSpot = exp(-d * d * 200.0);
        
        float dual = mix(wave, particleSpot, 0.5 + 0.5 * sin(time + fi));
        
        color += hsv2rgb(vec3(fi / 20.0, 0.9, 1.0)) * dual * 0.1;
    }
    
    // Entanglement visualization (correlated pairs)
    float entanglement = sin(pos.x * 10.0 + time) * sin(pos.y * 10.0 + time);
    color += vec3(1.0, 0.0, 0.5) * entanglement * 0.1;
    
    // Glow effect for high probability regions
    float glow = smoothstep(0.5, 1.0, prob);
    color += vec3(0.5, 0.8, 1.0) * glow * 0.3;
    
    // Vignette
    color *= 1.0 - length(centered) * 0.4;
    
    // Tone mapping
    color = color / (1.0 + color * 0.5);
    
    return vec4(color, 1.0);
}
