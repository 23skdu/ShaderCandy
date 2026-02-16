#version 450 core

#include "base/common.glsl"

// Wormhole - Wormhole/tunnel effect

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    vec2 p = centered;
    
    // Polar coordinates
    float r = length(p);
    float a = atan(p.y, p.x);
    
    // Wormhole distortion
    float tunnel = 1.0 / (r + 0.1);
    
    // Spiral pattern
    float spiral = sin(a * 5.0 + tunnel * 2.0 - t * 5.0);
    
    // Grid pattern along tunnel
    float gridU = fract(tunnel * 2.0 - t);
    float gridV = fract(a * 3.0 / PI);
    
    float grid = max(
        smoothstep(0.95, 1.0, gridU) + smoothstep(0.0, 0.05, gridU),
        smoothstep(0.95, 1.0, gridV) + smoothstep(0.0, 0.05, gridV)
    );
    
    // Color
    vec3 col = vec3(0.0);
    
    // Nebula background inside tunnel
    float nebula = fbm(vec3(p * tunnel, t * 0.2), 4);
    col += vec3(0.2, 0.1, 0.4) * nebula * 0.5;
    
    // Grid glow
    vec3 gridCol = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + tunnel * 0.5 + t);
    col += gridCol * grid * 0.8;
    
    // Spiral streaks
    col += vec3(0.5, 0.8, 1.0) * spiral * 0.3 * (1.0 - r);
    
    // Center singularity
    float singularity = smoothstep(0.05, 0.0, r);
    col = mix(col, vec3(0.0), singularity);
    
    // Event horizon ring
    float horizon = smoothstep(0.08, 0.05, r) - smoothstep(0.05, 0.02, r);
    col += vec3(1.0, 0.9, 0.7) * horizon;
    
    // Vignette
    col *= 1.0 - r * 0.5;
    
    col *= intensity;
    return vec4(col, alpha);
}
