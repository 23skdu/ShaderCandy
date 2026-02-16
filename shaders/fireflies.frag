#version 450 core

#include "base/common.glsl"

// Fireflies - Fireflies in a night scene

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    vec2 p = centered;
    
    // Night sky gradient
    vec3 col = mix(vec3(0.0, 0.02, 0.08), vec3(0.02, 0.05, 0.15), uv.y);
    
    // Stars
    float stars = pow(noise(uv * 300.0), 25.0);
    float stars2 = pow(noise(uv * 200.0 + 50.0), 20.0) * 0.7;
    col += vec3(0.9, 0.95, 1.0) * (stars + stars2);
    
    // Moon
    vec2 moonPos = vec2(0.6, 0.7);
    float moon = length(uv - moonPos);
    vec3 moonCol = vec3(0.95, 0.95, 0.8);
    col += moonCol * smoothstep(0.08, 0.06, moon);
    // Moon glow
    col += moonCol * 0.3 * smoothstep(0.15, 0.0, moon);
    
    // Ground silhouette (grass/trees)
    float ground = -0.4 + sin(p.x * 3.0) * 0.1 + sin(p.x * 7.0) * 0.05;
    float treeLine = step(ground, p.y);
    col = mix(vec3(0.02, 0.08, 0.03), col, treeLine);
    
    // Fireflies
    for(int i = 0; i < 20; i++) {
        float fi = float(i);
        
        // Firefly position (circular motion)
        float angle = fi * 0.5 + t * (0.5 + fi * 0.02);
        float radius = 0.3 + fi * 0.03;
        vec2 fireflyPos = vec2(
            cos(angle) * radius + sin(t * 0.3 + fi) * 0.2,
            sin(angle * 0.7) * 0.2 + 0.1 * sin(t * 0.5 + fi * 2.0) - 0.1
        );
        
        // Blinking
        float blink = 0.5 + 0.5 * sin(t * 3.0 + fi * 0.5);
        blink = pow(blink, 3.0);
        
        // Firefly glow
        float dist = length(p - fireflyPos);
        float glow = smoothstep(0.05, 0.0, dist) * blink;
        
        // Firefly color (yellow-green)
        vec3 fireflyCol = vec3(0.9, 1.0, 0.3);
        col += fireflyCol * glow;
        col += fireflyCol * 0.3 * smoothstep(0.15, 0.0, dist) * blink;
    }
    
    // Add subtle fog/mist
    float fog = snoise(vec3(p * 2.0, t * 0.1)) * 0.1;
    col = mix(col, vec3(0.05, 0.1, 0.15), fog);
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
