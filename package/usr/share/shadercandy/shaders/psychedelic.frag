#version 450 core

#include "base/common.glsl"

// Psychedelic - Psychedelic color patterns

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    vec2 p = centered;
    
    // Kaleidoscope effect
    float segments = 6.0;
    float angle = atan(p.y, p.x);
    float segmentAngle = TWO_PI / segments;
    
    // Fold into segment
    angle = mod(angle, segmentAngle) - segmentAngle * 0.5;
    p = vec2(cos(angle), sin(angle)) * length(p);
    
    // Rotation
    p *= rot(t);
    
    // Multiple layers of patterns
    vec3 col = vec3(0.0);
    
    for(float i = 0.0; i < 5.0; i++) {
        vec2 q = p * (2.0 + i * 0.5);
        
        // Swirling pattern
        float spiral = sin(length(q) * 5.0 - t * (2.0 + i) + atan(q.y, q.x) * 3.0);
        
        // Ripple pattern
        float ripple = sin(q.x * 4.0 + t) * cos(q.y * 4.0 - t);
        
        // Combine
        float pattern = spiral + ripple * 0.5;
        
        // Color based on pattern
        vec3 layerCol = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + pattern + t + i * 0.5);
        
        col += layerCol * (0.2 - i * 0.03);
    }
    
    // Center glow
    float glow = smoothstep(0.5, 0.0, length(centered));
    col += vec3(1.0, 0.8, 0.9) * glow * 0.5;
    
    // Saturation boost
    col = pow(col, vec3(0.8));
    
    col *= intensity;
    return vec4(col, alpha);
}
