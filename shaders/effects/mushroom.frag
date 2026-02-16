#version 450 core

#include "base/common.glsl"

// Mushroom - 3D rotating neon mushrooms on fractal background

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Mushroom SDF
float sdMushroom(vec3 p, float t) {
    // Cap (sphere-like)
    float cap = length(p - vec3(0.0, 0.3, 0.0)) - 0.4;
    
    // Stalk (cylinder-like)
    float stalk = length(vec2(p.x, p.z)) - 0.12;
    stalk = max(stalk, abs(p.y + 0.1) - 0.4);
    
    // Combine
    return min(cap, stalk);
}

// Scene SDF
float map(vec3 p, float t) {
    float d = 100.0;
    
    // Multiple mushrooms as particles
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        
        // Position
        vec3 pos = vec3(
            sin(fi * 1.3 + t * 0.5) * 1.5,
            sin(fi * 0.7 + t * 0.3) * 0.3,
            cos(fi * 1.1 + t * 0.4) * 1.5
        );
        
        // Individual mushroom
        vec3 q = p - pos;
        
        // Rotate on X axis
        q.yz *= rot(t * (0.5 + fi * 0.1) + fi);
        
        // Scale varies
        float s = 0.3 + fi * 0.05;
        q /= s;
        
        float mushroom = sdMushroom(q, t) * s;
        d = min(d, mushroom);
    }
    
    return d;
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, float t) {
    float dO = 0.0;
    
    for(int i = 0; i < 64; i++) {
        vec3 p = ro + rd * dO;
        float dS = map(p, t);
        
        dO += dS;
        if(dO > 20.0 || dS < 0.001) break;
    }
    
    return dO;
}

// Normal calculation
vec3 calcNormal(vec3 p, float t) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy, t) - map(p - e.xyy, t),
        map(p + e.yxy, t) - map(p - e.yxy, t),
        map(p + e.yyx, t) - map(p - e.yyx, t)
    ));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    
    // Camera
    vec3 ro = vec3(cos(t * 0.3) * 3.0, 0.5 + sin(t * 0.2) * 0.3, sin(t * 0.3) * 3.0);
    vec3 ta = vec3(0.0, 0.0, 0.0);
    
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Background - fractal neon
    vec3 col = vec3(0.0);
    float bg = fbm(vec3(uv * 5.0, t * 0.1), 4);
    col = vec3(0.1, 0.0, 0.2) * bg;
    col += vec3(0.0, 0.3, 0.5) * (1.0 - bg) * 0.5;
    
    // Ray march
    float d = rayMarch(ro, rd, t);
    
    if(d < 20.0) {
        vec3 p = ro + rd * d;
        vec3 n = calcNormal(p, t);
        
        // Lighting
        vec3 lightDir = normalize(vec3(1.0, 2.0, 1.0));
        float diff = max(dot(n, lightDir), 0.0);
        float spec = pow(max(dot(reflect(-lightDir, n), -rd), 0.0), 32.0);
        
        // Rainbow color shifting
        vec3 mushroomCol = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + t + p.y * 2.0);
        
        col = mushroomCol * (0.2 + 0.8 * diff) + vec3(0.5) * spec;
        
        // Glow
        col += mushroomCol * 0.3;
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
