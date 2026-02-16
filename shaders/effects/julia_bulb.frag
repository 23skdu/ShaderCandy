#version 450 core

#include "base/common.glsl"

// Julia Bulb - 3D Julia set with power-8 bulb

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Julia bulb SDF
float juliaBulb(vec3 p, vec3 c) {
    vec3 z = p;
    float dr = 1.0;
    float r = 0.0;
    int iterations = 0;
    
    for(int i = 0; i < 12; i++) {
        r = length(z);
        if(r > 4.0) break;
        
        // Convert to spherical
        float theta = acos(clamp(z.z / r, -1.0, 1.0));
        float phi = atan(z.y, z.x);
        
        dr = pow(r, 7.0) * 8.0 * dr + 1.0;
        
        // z = z^8 + c
        float zr = pow(r, 8.0);
        theta = theta * 8.0;
        phi = phi * 8.0;
        
        z = zr * vec3(
            sin(theta) * cos(phi),
            sin(phi) * sin(theta),
            cos(theta)
        );
        z += c;
        
        iterations++;
    }
    
    return 0.5 * log(r) * r / dr;
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, vec3 c) {
    float dO = 0.0;
    
    for(int i = 0; i < 64; i++) {
        vec3 p = ro + rd * dO;
        float dS = juliaBulb(p, c);
        
        dO += dS;
        if(dO > 10.0 || dS < 0.001) break;
    }
    
    return dO;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.15;
    
    // Animate Julia constant
    vec3 c = vec3(
        0.5 + 0.3 * sin(t * 0.5),
        0.3 + 0.3 * cos(t * 0.4),
        0.2 + 0.2 * sin(t * 0.6)
    );
    
    // Camera
    vec3 ro = vec3(cos(t * 0.3) * 2.0, sin(t * 0.2) * 1.0, sin(t * 0.3) * 2.0);
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
        
        // Color based on position
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + p * 0.3 + t);
        
        // Glow
        float glow = exp(-d * 0.5);
        col += vec3(0.5, 0.2, 0.6) * glow;
    }
    
    // Background
    col += vec3(0.01, 0.01, 0.03) * (1.0 - exp(-d * 0.2));
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
