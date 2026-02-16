#version 450 core

#include "base/common.glsl"

// Julia 4D - Quaternion Julia set in 4D

// Quaternion multiplication
vec4 qMult(vec4 a, vec4 b) {
    return vec4(
        a.x * b.x - a.y * b.y - a.z * b.z - a.w * b.w,
        a.x * b.y + a.y * b.x + a.z * b.w - a.w * b.z,
        a.x * b.z - a.y * b.w + a.z * b.x + a.w * b.y,
        a.x * b.w + a.y * b.z - a.z * b.y + a.w * b.x
    );
}

// 4D Julia set SDF
float julia4D(vec4 z, vec4 c) {
    vec4 dz = vec4(1.0, 0.0, 0.0, 0.0);
    float m2 = 0.0;
    
    for(int i = 0; i < 16; i++) {
        dz = 2.0 * qMult(z, dz);
        z = qMult(z, z) + c;
        
        m2 = dot(z, z);
        if(m2 > 256.0) break;
    }
    
    float d = 0.5 * sqrt(m2 / dot(dz, dz)) * log(m2);
    return d;
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, vec4 c) {
    float dO = 0.0;
    
    for(int i = 0; i < 64; i++) {
        vec3 p = ro + rd * dO;
        vec4 z = vec4(p, 0.0);
        float dS = julia4D(z, c);
        
        dO += dS;
        if(dO > 10.0 || dS < 0.001) break;
    }
    
    return dO;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    
    // Animate Julia constant in 4D
    vec4 c = vec4(
        0.4 + 0.2 * sin(t * 0.5),
        0.2 + 0.2 * cos(t * 0.3),
        0.3 + 0.2 * sin(t * 0.7),
        0.1 + 0.15 * cos(t * 0.4)
    );
    
    // Camera
    vec3 ro = vec3(cos(t * 0.3) * 2.5, sin(t * 0.2) * 1.5, sin(t * 0.3) * 2.5);
    vec3 ta = vec3(0.0);
    
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Ray march
    float d = rayMarch(ro, rd, c);
    
    vec3 col = vec3(0.0);
    
    if(d < 10.0) {
        vec3 p = ro + rd * d;
        
        // Color based on position and Julia constant
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + p * 0.5 + t);
        
        // Glow
        float glow = exp(-d * 0.5);
        col += vec3(0.5, 0.3, 0.7) * glow;
    }
    
    // Background
    col += vec3(0.01, 0.02, 0.05) * (1.0 - exp(-d * 0.2));
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
