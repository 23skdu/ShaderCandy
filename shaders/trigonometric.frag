#version 450 core

#include "base/common.glsl"

// Trigonometric - Trigonometric function visualization

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    vec2 p = centered;
    
    // Dark background with grid
    vec3 col = vec3(0.02, 0.02, 0.05);
    
    // Grid lines
    vec2 grid = abs(fract(p * 4.0) - 0.5);
    float gridLine = smoothstep(0.48, 0.5, max(grid.x, grid.y));
    col += vec3(0.05) * gridLine;
    
    // Axes
    float axes = smoothstep(0.01, 0.0, min(abs(p.x), abs(p.y)));
    col += vec3(0.1, 0.1, 0.15) * axes;
    
    // Sine wave
    float sineY = sin(p.x * 5.0 + t) * 0.3;
    float sine = smoothstep(0.03, 0.0, abs(p.y - sineY));
    vec3 sineCol = vec3(1.0, 0.3, 0.3);
    col = mix(col, sineCol, sine);
    
    // Cosine wave
    float cosY = cos(p.x * 5.0 + t * 0.8) * 0.3;
    float cosine = smoothstep(0.03, 0.0, abs(p.y - cosY));
    vec3 cosCol = vec3(0.3, 0.3, 1.0);
    col = mix(col, cosCol, cosine);
    
    // Tangent wave (clamped)
    float tanY = tan(p.x * 3.0 + t * 0.5) * 0.1;
    tanY = clamp(tanY, -0.8, 0.8);
    float tangent = smoothstep(0.02, 0.0, abs(p.y - tanY));
    vec3 tanCol = vec3(0.3, 1.0, 0.3);
    col = mix(col, tanCol, tangent);
    
    // Lissajous curve (parametric)
    for(float i = 0.0; i < 200.0; i++) {
        float theta = i / 200.0 * TWO_PI;
        float x = sin(theta * 3.0 + t) * 0.4;
        float y = sin(theta * 4.0) * 0.4;
        
        float dist = length(p - vec2(x, y));
        col += vec3(1.0, 0.8, 0.2) * smoothstep(0.015, 0.0, dist) * 0.5;
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
