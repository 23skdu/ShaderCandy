#version 450 core

#include "base/common.glsl"

// Ocean - Ocean waves and caustics

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Wave function
float wave(vec2 p, float t) {
    float w = 0.0;
    
    // Multiple wave layers
    w += sin(p.x * 2.0 + t) * 0.5;
    w += sin(p.y * 3.0 + t * 0.8) * 0.3;
    w += sin((p.x + p.y) * 4.0 + t * 1.2) * 0.2;
    w += sin(length(p) * 5.0 - t * 1.5) * 0.15;
    
    return w;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    vec2 p = centered;
    
    // Sky gradient
    vec3 sky = mix(vec3(0.4, 0.7, 0.9), vec3(0.6, 0.85, 1.0), uv.y);
    
    // Horizon
    float horizon = 0.0;
    
    // Water
    vec3 waterDeep = vec3(0.0, 0.2, 0.4);
    vec3 waterShallow = vec3(0.1, 0.4, 0.6);
    
    // Calculate waves
    float waveHeight = wave(p * 2.0, t) * 0.1;
    float waves = p.y + waveHeight;
    
    vec3 col;
    
    if(p.y < horizon) {
        // Under water
        col = mix(waterDeep, waterShallow, smoothstep(-1.0, 0.0, p.y));
        
        // Caustics
        float caustics = 0.0;
        for(int i = 0; i < 3; i++) {
            float fi = float(i);
            vec2 causticUV = p * (3.0 + fi) + t * (0.5 + fi * 0.2);
            caustics += sin(causticUV.x + sin(causticUV.y)) * 
                       sin(causticUV.y + sin(causticUV.x));
        }
        caustics = smoothstep(-0.5, 1.0, caustics) * 0.3;
        
        col += vec3(0.4, 0.7, 0.9) * caustics * (1.0 - smoothstep(-0.5, 0.0, p.y));
        
        // Wave foam
        float foam = smoothstep(0.05, 0.0, abs(waves - horizon));
        col = mix(col, vec3(0.9, 0.95, 1.0), foam);
        
    } else {
        // Sky with reflection
        col = sky;
        
        // Sun
        vec2 sunPos = vec2(0.3, 0.6);
        float sun = length(uv - sunPos);
        col += vec3(1.0, 0.9, 0.7) * smoothstep(0.1, 0.0, sun);
        
        // Reflection on water
        float reflection = smoothstep(0.0, -0.2, p.y);
        vec3 reflectCol = mix(waterDeep, vec3(0.8, 0.9, 1.0), 0.3);
        col = mix(col, reflectCol, reflection * 0.5);
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
