#version 450 core

#include "base/common.glsl"

// Nebula - Colorful space gas clouds

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = centered;
    float t = time * speed * 0.1;
    
    // Deep space background
    vec3 color = vec3(0.01, 0.01, 0.02);
    
    // Multiple nebula layers
    vec3 nebula = vec3(0.0);
    
    // Layer 1 - purple/pink
    float n1 = fbm(vec3(p * 2.0, t * 0.2), 5);
    n1 = smoothstep(0.0, 0.8, n1);
    vec3 nebula1 = vec3(0.6, 0.2, 0.8) * n1;
    
    // Layer 2 - blue/cyan
    float n2 = fbm(vec3(p * 3.0 + 5.0, t * 0.15 + 3.0), 5);
    n2 = smoothstep(0.1, 0.7, n2);
    vec3 nebula2 = vec3(0.2, 0.5, 0.9) * n2;
    
    // Layer 3 - orange/red
    float n3 = fbm(vec3(p * 1.5 + 10.0, t * 0.25 + 7.0), 5);
    n3 = smoothstep(0.2, 0.75, n3);
    vec3 nebula3 = vec3(0.9, 0.4, 0.2) * n3;
    
    nebula = nebula1 + nebula2 + nebula3;
    
    // Stars
    float stars = pow(noise(p * 300.0), 25.0);
    float stars2 = pow(noise(p * 150.0 + 50.0), 20.0) * 0.7;
    
    // Twinkling
    float twinkle = sin(t * 5.0 + p.x * 100.0) * 0.3 + 0.7;
    stars *= twinkle;
    
    // Combine
    color += nebula * 0.6;
    color += vec3(1.0, 0.98, 0.95) * (stars + stars2);
    
    // Add glow
    color += nebula * 0.2;
    
    color *= intensity;
    return vec4(color, alpha);
}
