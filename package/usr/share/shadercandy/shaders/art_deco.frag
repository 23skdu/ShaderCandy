#version 450 core

#include "base/common.glsl"

// Art Deco - Geometric art deco patterns

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Art deco pattern
float artDecoPattern(vec2 p, float t) {
    float d = 100.0;
    
    // Sunburst rays
    float rays = 12.0;
    float angle = atan(p.y, p.x);
    float radius = length(p);
    
    float ray = abs(sin(angle * rays * 0.5 + t * 0.5));
    ray = smoothstep(0.8, 1.0, ray) * smoothstep(1.5, 0.0, radius);
    
    // Geometric circles
    float circles = 0.0;
    for(float i = 0.0; i < 3.0; i++) {
        float r = 0.3 + i * 0.25;
        float c = abs(length(p) - r);
        circles += smoothstep(0.02, 0.0, c);
    }
    
    // Zigzag patterns
    vec2 zigzag = p;
    zigzag.x += sin(zigzag.y * 20.0 + t) * 0.1;
    float zig = smoothstep(0.01, 0.0, abs(sin(zigzag.x * 30.0)) * 0.05);
    
    return ray + circles * 0.5 + zig;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    vec2 p = centered;
    
    // Background - art deco colors
    vec3 bg1 = vec3(0.1, 0.05, 0.15); // Deep purple
    vec3 bg2 = vec3(0.2, 0.15, 0.1);  // Warm brown
    vec3 col = mix(bg1, bg2, uv.y + sin(t * 0.5) * 0.2);
    
    // Rotate pattern
    p *= rot(t * 0.1);
    
    // Pattern
    float pattern = artDecoPattern(p, t);
    
    // Art deco colors - gold and black
    vec3 gold = vec3(0.9, 0.75, 0.3);
    vec3 bronze = vec3(0.7, 0.5, 0.2);
    vec3 patternCol = mix(bronze, gold, sin(t * 0.3 + length(p) * 3.0) * 0.5 + 0.5);
    
    // Apply pattern
    col = mix(col, patternCol, pattern);
    
    // Border decoration
    float border = max(abs(p.x), abs(p.y));
    float borderPattern = smoothstep(0.95, 0.98, border) - smoothstep(0.98, 1.0, border);
    col = mix(col, gold, borderPattern);
    
    // Corner decorations
    vec2 corner = abs(p) - vec2(0.85);
    float cornerDeco = smoothstep(0.1, 0.0, length(max(corner, 0.0)));
    col += gold * cornerDeco * 0.5;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
