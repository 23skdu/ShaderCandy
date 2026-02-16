#version 450 core

#include "base/common.glsl"

// Rain - Rain falling effect

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    vec2 p = centered;
    
    // Stormy sky
    vec3 col = mix(vec3(0.1, 0.12, 0.15), vec3(0.15, 0.15, 0.2), uv.y);
    
    // Clouds
    float clouds = fbm(vec3(p * 2.0, t * 0.1), 4);
    col = mix(col, vec3(0.2, 0.2, 0.25), smoothstep(0.3, 0.6, clouds));
    
    // Rain drops
    float rain = 0.0;
    for(int i = 0; i < 50; i++) {
        float fi = float(i);
        
        // Rain position
        vec2 rainPos = vec2(
            mod(fi * 0.5 + t * (0.5 + fi * 0.01), 3.0) - 1.5,
            mod(fi * 0.3 - t * (1.0 + fi * 0.005), 2.0) - 1.0
        );
        
        // Rain drop shape (elongated)
        vec2 rainUV = p - rainPos;
        rainUV.y *= 4.0; // Elongate
        
        float drop = smoothstep(0.02, 0.0, length(rainUV));
        rain += drop;
    }
    
    // Rain color
    vec3 rainCol = vec3(0.7, 0.8, 0.9);
    col += rainCol * rain * 0.3;
    
    // Lightning flash
    float lightning = 0.0;
    if(hash(t * 0.1) > 0.97) {
        lightning = smoothstep(0.0, 0.1, fract(t * 2.0)) * 
                   (1.0 - smoothstep(0.1, 0.2, fract(t * 2.0)));
    }
    col += vec3(0.9, 0.95, 1.0) * lightning;
    
    // Ground/water reflection
    if(p.y < -0.6) {
        col = mix(vec3(0.05, 0.05, 0.08), col, smoothstep(-0.8, -0.6, p.y));
        // Reflection of rain
        col += rainCol * rain * 0.1 * smoothstep(-0.8, -0.6, p.y);
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
