#version 450 core

#include "base/common.glsl"

// Julia - 2D Julia set fractal

// Complex number operations
vec2 cMul(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 cSqr(vec2 z) {
    return vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

float julia(vec2 z, vec2 c) {
    float n = 0.0;
    
    for(int i = 0; i < 100; i++) {
        z = cSqr(z) + c;
        n += 1.0;
        
        if(dot(z, z) > 4.0) break;
    }
    
    return n;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    
    // Scale and position
    vec2 z = centered * 2.0;
    
    // Animated Julia constant
    vec2 c = vec2(
        0.7885 * cos(t * 0.3),
        0.7885 * sin(t * 0.3)
    );
    
    // Calculate Julia set
    float iterations = julia(z, c);
    
    // Color based on iterations
    float smoothIter = iterations / 100.0;
    
    vec3 col;
    if(iterations >= 99.0) {
        // Inside set - black
        col = vec3(0.0);
    } else {
        // Outside set - smooth coloring
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + smoothIter * 10.0 + t);
        col *= smoothIter * 2.0;
    }
    
    // Glow effect
    col += vec3(0.1, 0.2, 0.4) * smoothIter * 0.5;
    
    return vec4(col * intensity, alpha);
}
