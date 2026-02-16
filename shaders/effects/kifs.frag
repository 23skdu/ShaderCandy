#version 450 core

#include "base/common.glsl"

// KIFS - Kaleidoscopic Iterated Function System

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// KIFS transformation
vec3 kifs(vec3 p, float t) {
    float scale = 2.0;
    vec3 offset = vec3(1.0, 0.5, 0.3);
    
    for(int i = 0; i < 6; i++) {
        // Fold
        p = abs(p) - offset;
        
        // Rotate
        p.xy *= rot(t * 0.2 + float(i) * 0.4);
        p.xz *= rot(t * 0.15 + float(i) * 0.3);
        
        // Scale
        p *= scale;
    }
    
    return p;
}

// Distance estimator
float de(vec3 p, float t) {
    vec3 q = kifs(p, t);
    return length(q) * pow(0.5, 6.0);
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, float t) {
    float dO = 0.0;
    
    for(int i = 0; i < 80; i++) {
        vec3 p = ro + rd * dO;
        float dS = de(p, t);
        
        dO += dS;
        if(dO > 15.0 || dS < 0.001) break;
    }
    
    return dO;
}

// Normal calculation
vec3 calcNormal(vec3 p, float t) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        de(p + e.xyy, t) - de(p - e.xyy, t),
        de(p + e.yxy, t) - de(p - e.yxy, t),
        de(p + e.yyx, t) - de(p - e.yyx, t)
    ));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    
    // Camera
    vec3 ro = vec3(cos(t * 0.4) * 3.0, sin(t * 0.3) * 1.5, sin(t * 0.4) * 3.0);
    vec3 ta = vec3(0.0);
    
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Ray march
    float d = rayMarch(ro, rd, t);
    
    vec3 col = vec3(0.0);
    
    if(d < 15.0) {
        vec3 p = ro + rd * d;
        vec3 n = calcNormal(p, t);
        
        // Lighting
        vec3 lightDir = normalize(vec3(1.0, 2.0, 1.0));
        float diff = max(dot(n, lightDir), 0.0);
        float spec = pow(max(dot(reflect(-lightDir, n), -rd), 0.0), 32.0);
        
        // Color based on iteration depth
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + length(p) * 0.3 + t);
        
        col = col * (0.2 + 0.8 * diff) + vec3(0.5) * spec;
        
        // Fog
        col *= exp(-d * 0.1);
    } else {
        // Background
        col = vec3(0.02, 0.01, 0.05);
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
