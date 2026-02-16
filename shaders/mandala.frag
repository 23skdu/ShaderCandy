#version 450 core

#include "base/common.glsl"

// Mandala - Geometric mandala patterns

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Mandala pattern
float mandala(vec2 p, float t) {
    float pattern = 0.0;
    
    // Polar coordinates
    float r = length(p);
    float a = atan(p.y, p.x);
    
    // Number of segments
    float segments = 8.0;
    
    // Radial symmetry
    float angle = mod(a, TWO_PI / segments) - PI / segments;
    vec2 symP = vec2(cos(angle), sin(angle)) * r;
    
    // Concentric rings
    for(float i = 1.0; i <= 5.0; i++) {
        float ringR = i * 0.15;
        float ring = abs(r - ringR) - 0.01;
        pattern += smoothstep(0.01, 0.0, ring);
        
        // Decorative elements on rings
        float decoAngle = a * segments * i + t;
        float deco = smoothstep(0.05, 0.0, abs(r - ringR) + 0.02);
        deco *= smoothstep(0.5, 1.0, sin(decoAngle));
        pattern += deco * 0.5;
    }
    
    // Petal shapes
    float petals = 6.0;
    float petalAngle = a * petals + t * 0.5;
    float petal = sin(petalAngle) * 0.1 + 0.3;
    float petalShape = smoothstep(0.02, 0.0, abs(r - petal));
    pattern += petalShape;
    
    // Center
    float center = smoothstep(0.08, 0.0, r);
    pattern += center;
    
    return pattern;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    vec2 p = centered;
    
    // Dark background
    vec3 col = vec3(0.02, 0.01, 0.05);
    
    // Slow rotation
    p *= rot(t * 0.2);
    
    // Mandala pattern
    float pattern = mandala(p, t);
    
    // Mandala colors
    vec3 color1 = vec3(0.8, 0.3, 0.6); // Pink
    vec3 color2 = vec3(0.3, 0.6, 0.9); // Blue
    vec3 color3 = vec3(0.9, 0.7, 0.2); // Gold
    
    // Color based on radius
    float r = length(p);
    vec3 patternCol = mix(color1, color2, smoothstep(0.0, 0.5, r));
    patternCol = mix(patternCol, color3, smoothstep(0.5, 0.8, r));
    
    // Apply pattern
    col = mix(col, patternCol, pattern);
    
    // Glow
    col += patternCol * pattern * 0.3;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
