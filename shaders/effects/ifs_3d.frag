#version 450 core

#include "base/common.glsl"

// IFS 3D - Iterated Function System in 3D

// Rotation matrix
mat2 rot2D(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// IFS transformation
vec3 ifsTransform(vec3 p, float t) {
    float scale = 2.0;
    vec3 offset = vec3(0.8, 0.5, 0.3);
    
    float d = 100.0;
    
    for (int i = 0; i < 5; i++) {
        p = abs(p) - offset;
        p.xz *= rot2D(t * 0.3 + float(i) * 0.5);
        p.yz *= rot2D(t * 0.2 + float(i) * 0.3);
        p *= scale;
        
        float dist = length(p) / scale;
        d = min(d, dist);
    }
    
    return p;
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, float t) {
    float dO = 0.0;
    
    for(int i = 0; i < 64; i++) {
        vec3 p = ro + rd * dO;
        vec3 q = ifsTransform(p, t);
        float dS = length(q) * 0.1;
        
        dO += dS;
        if(dO > 20.0 || dS < 0.001) break;
    }
    
    return dO;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    
    // Camera
    vec3 ro = vec3(cos(t * 0.5) * 3.0, sin(t * 0.3) * 2.0, sin(t * 0.5) * 3.0);
    vec3 ta = vec3(0.0);
    
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Ray march
    float d = rayMarch(ro, rd, t);
    
    vec3 col = vec3(0.0);
    
    if(d < 20.0) {
        vec3 p = ro + rd * d;
        vec3 q = ifsTransform(p, t);
        
        // Color based on position and iteration
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + length(q) * 0.5 + t);
        
        // Glow
        float glow = exp(-d * 0.3);
        col += vec3(0.3, 0.5, 0.8) * glow;
    }
    
    // Background gradient
    col += vec3(0.02, 0.01, 0.05) * (1.0 - exp(-d * 0.1));
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
