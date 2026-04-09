#version 450 core

#include "base/common.glsl"

// Waterfall - Cascading waterfall effect

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    vec2 p = centered;
    
    // Sky/cliff background
    vec3 col = mix(vec3(0.2, 0.3, 0.35), vec3(0.3, 0.4, 0.45), uv.y);
    
    // Cliff sides
    float cliffLeft = -0.3 + sin(p.y * 2.0) * 0.1;
    float cliffRight = 0.3 + sin(p.y * 2.0 + 2.0) * 0.1;
    
    vec3 cliffCol = vec3(0.4, 0.35, 0.3);
    col = mix(col, cliffCol, step(p.x, cliffLeft));
    col = mix(col, cliffCol, step(cliffRight, p.x));
    
    // Waterfall area
    if(p.x > cliffLeft && p.x < cliffRight) {
        // Water flow
        float flow = p.y - t * 0.5;
        
        // Water noise
        float waterNoise = snoise(vec3(p.x * 5.0, flow * 3.0, t));
        waterNoise += snoise(vec3(p.x * 10.0, flow * 6.0, t * 2.0)) * 0.5;
        
        // Water color
        vec3 waterDeep = vec3(0.1, 0.3, 0.5);
        vec3 waterFoam = vec3(0.9, 0.95, 1.0);
        
        // Foam on edges and where noise is high
        float foam = smoothstep(0.3, 0.7, waterNoise);
        foam += smoothstep(0.05, 0.0, min(abs(p.x - cliffLeft), abs(p.x - cliffRight)));
        
        vec3 waterCol = mix(waterDeep, waterFoam, foam);
        
        // Add motion blur/flow
        waterCol += vec3(0.2, 0.4, 0.6) * sin(flow * 10.0) * 0.1;
        
        col = waterCol;
        
        // Mist at bottom
        if(p.y < -0.5) {
            float mist = snoise(vec3(p.x * 3.0, (p.y + 0.5) * 5.0, t));
            mist *= smoothstep(-0.5, -0.8, p.y);
            col = mix(col, vec3(0.8, 0.9, 1.0), mist * 0.5);
        }
    }
    
    // Pool at bottom
    if(p.y < -0.7) {
        vec3 poolCol = vec3(0.15, 0.35, 0.55);
        col = mix(poolCol, col, smoothstep(-0.9, -0.7, p.y));
        
        // Ripples
        float ripples = sin(length(p) * 20.0 - t * 3.0);
        col += vec3(0.1, 0.2, 0.3) * ripples * 0.1;
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
