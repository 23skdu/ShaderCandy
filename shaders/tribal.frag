#version 450 core

#include "base/common.glsl"

// Tribal - Tribal art patterns

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Tribal pattern
float tribalPattern(vec2 p, float t) {
    float pattern = 0.0;
    
    // Radial symmetry
    float segments = 4.0;
    float angle = atan(p.y, p.x);
    float segmentAngle = TWO_PI / segments;
    angle = mod(angle, segmentAngle) - segmentAngle * 0.5;
    vec2 symP = vec2(cos(angle), sin(angle)) * length(p);
    
    // Curved lines
    for(float i = 0.0; i < 6.0; i++) {
        float fi = i;
        float curve = sin(symP.x * (2.0 + fi * 0.5) + t + fi) * 0.2;
        float line = smoothstep(0.03, 0.0, abs(symP.y - curve - fi * 0.08));
        pattern += line;
    }
    
    // Sharp points
    float points = sin(symP.x * 10.0 + t) * exp(-abs(symP.y) * 5.0);
    pattern += smoothstep(0.5, 1.0, points) * 0.5;
    
    // Center circle
    float center = smoothstep(0.1, 0.0, length(symP));
    pattern += center;
    
    return pattern;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.15;
    vec2 p = centered;
    
    // Dark background
    vec3 col = vec3(0.05, 0.03, 0.02);
    
    // Rotate slowly
    p *= rot(t * 0.1);
    
    // Pattern
    float pattern = tribalPattern(p, t);
    
    // Tribal colors
    vec3 patternCol = mix(
        vec3(0.8, 0.6, 0.3), // Gold/brown
        vec3(0.9, 0.3, 0.1), // Orange/red
        sin(t + length(p) * 3.0) * 0.5 + 0.5
    );
    
    // Apply pattern
    col = mix(col, patternCol, pattern);
    
    // Glow
    col += patternCol * pattern * 0.2;
    
    // Border
    float border = max(abs(p.x), abs(p.y));
    col = mix(col, patternCol, smoothstep(0.95, 0.98, border) - smoothstep(0.98, 1.0, border));
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
