#version 450 core

#include "base/common.glsl"

// Celtic - Celtic knot patterns

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Celtic knot pattern
float celticKnot(vec2 p, float t) {
    float pattern = 0.0;
    
    // Scale for knot detail
    vec2 uv = p * 3.0;
    
    // Base weave pattern
    float wave1 = sin(uv.x * 3.0 + t) * 0.3;
    float wave2 = sin(uv.y * 3.0 + t * 0.7) * 0.3;
    
    // Interlacing effect
    float interlace = sin(uv.x * 2.0 + wave2) * sin(uv.y * 2.0 + wave1);
    
    // Knot thickness
    float thickness = 0.15;
    
    // Horizontal strands
    float hStrand = smoothstep(thickness, thickness * 0.5, 
                               abs(fract(uv.y + wave1) - 0.5) * 2.0);
    
    // Vertical strands  
    float vStrand = smoothstep(thickness, thickness * 0.5,
                               abs(fract(uv.x + wave2) - 0.5) * 2.0);
    
    // Over-under pattern
    float overUnder = step(0.0, sin(uv.x * 6.0 + t) * sin(uv.y * 6.0));
    
    // Combine strands with interlacing
    if(overUnder > 0.5) {
        pattern = max(hStrand * (1.0 - vStrand * 0.5), vStrand * (1.0 - hStrand * 0.5));
    } else {
        pattern = max(vStrand * (1.0 - hStrand * 0.5), hStrand * (1.0 - vStrand * 0.5));
    }
    
    // Add border
    vec2 border = abs(fract(uv) - 0.5);
    float borderLine = smoothstep(0.48, 0.5, max(border.x, border.y));
    pattern += borderLine * 0.5;
    
    return pattern;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.15;
    vec2 p = centered;
    
    // Background - parchment color
    vec3 col = vec3(0.85, 0.78, 0.65);
    
    // Celtic colors
    vec3 knotColor = vec3(0.2, 0.35, 0.2); // Dark green
    vec3 highlightColor = vec3(0.4, 0.6, 0.3); // Light green
    vec3 shadowColor = vec3(0.1, 0.15, 0.1); // Dark shadow
    
    // Pattern
    float pattern = celticKnot(p, t);
    
    // Apply pattern with shading
    vec3 patternCol = mix(col, knotColor, pattern);
    
    // Add depth/shadow to interlacing
    vec2 uv = p * 3.0;
    float shadow = sin(uv.x * 6.0 + t) * sin(uv.y * 6.0);
    patternCol += shadowColor * shadow * pattern * 0.2;
    
    // Highlight
    patternCol += highlightColor * pattern * 0.1;
    
    // Aged parchment effect
    float age = snoise(vec3(p * 2.0, t * 0.1));
    patternCol *= 0.9 + 0.1 * age;
    
    // Vignette
    patternCol *= 1.0 - length(centered) * 0.2;
    
    col = patternCol;
    
    col *= intensity;
    return vec4(col, alpha);
}
