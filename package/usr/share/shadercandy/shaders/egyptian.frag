#version 450 core

#include "base/common.glsl"

// Egyptian - Egyptian-themed patterns and symbols

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Pyramid SDF
float sdPyramid(vec2 p, float width, float height) {
    p.x = abs(p.x);
    float slope = height / width;
    float y = height - p.x * slope;
    return max(p.y - y, -p.y);
}

// Eye of Horus pattern
float eyeOfHorus(vec2 p) {
    float d = 100.0;
    
    // Eye outline
    float eye = length(p * vec2(2.0, 1.0) - vec2(0.0, 0.0)) - 0.3;
    eye = abs(eye) - 0.02;
    
    // Pupil
    float pupil = length(p - vec2(-0.05, 0.0)) - 0.08;
    
    // Eyebrow
    float brow = abs(p.y - 0.35) - 0.02;
    brow = max(brow, abs(p.x) - 0.4);
    
    // Lines below eye
    float line1 = abs(p.x - 0.1) - 0.02;
    line1 = max(line1, abs(p.y + 0.35) - 0.05);
    
    float line2 = abs(p.x - 0.25) - 0.02;
    line2 = max(line2, abs(p.y + 0.25) - 0.05);
    
    return min(min(eye, brow), min(line1, line2));
}

// Ankh symbol
float ankh(vec2 p) {
    float d = 100.0;
    
    // Top loop
    float loop = abs(length(p - vec2(0.0, 0.2)) - 0.15) - 0.03;
    
    // Vertical bar
    float vBar = abs(p.x) - 0.03;
    vBar = max(vBar, abs(p.y + 0.1) - 0.35);
    
    // Horizontal bar
    float hBar = abs(p.y + 0.05) - 0.03;
    hBar = max(hBar, abs(p.x) - 0.25);
    
    return min(loop, min(vBar, hBar));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    vec2 p = centered;
    
    // Desert sky gradient
    vec3 col = mix(vec3(0.9, 0.7, 0.4), vec3(0.6, 0.4, 0.2), uv.y);
    
    // Pyramids
    float pyramid1 = sdPyramid(p - vec2(-0.4, -0.3), 0.4, 0.5);
    float pyramid2 = sdPyramid(p - vec2(0.3, -0.35), 0.3, 0.4);
    
    vec3 pyramidCol = vec3(0.8, 0.6, 0.3);
    col = mix(col, pyramidCol, 1.0 - smoothstep(0.0, 0.01, pyramid1));
    col = mix(col, pyramidCol * 0.9, 1.0 - smoothstep(0.0, 0.01, pyramid2));
    
    // Sand dunes
    float dune = sin(p.x * 3.0 + t * 0.5) * 0.1;
    float sand = step(-0.5, p.y + dune);
    vec3 sandCol = vec3(0.9, 0.75, 0.5);
    col = mix(col, sandCol, sand * (1.0 - step(-0.3, p.y)));
    
    // Eye of Horus (overlay)
    vec2 eyePos = vec2(0.5, 0.4);
    float eye = eyeOfHorus((p - eyePos) * 1.5);
    vec3 eyeCol = vec3(0.2, 0.5, 0.8);
    col = mix(col, eyeCol, 1.0 - smoothstep(0.0, 0.01, eye));
    
    // Ankh symbol
    vec2 ankhPos = vec2(-0.5, 0.4);
    float ankhSym = ankh((p - ankhPos) * 1.5);
    vec3 ankhCol = vec3(0.8, 0.6, 0.2);
    col = mix(col, ankhCol, 1.0 - smoothstep(0.0, 0.01, ankhSym));
    
    // Hieroglyph-like decorations
    vec2 hieroUV = p * 10.0;
    float hiero = step(0.7, hash(floor(hieroUV.x) + floor(hieroUV.y) * 57.0));
    hiero *= step(0.4, fract(hieroUV.y));
    col += vec3(0.6, 0.4, 0.2) * hiero * 0.3;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
