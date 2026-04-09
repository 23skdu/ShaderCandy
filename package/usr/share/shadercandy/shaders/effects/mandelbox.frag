#version 450 core

#include "base/common.glsl"

// Mandelbox - 3D Mandelbrot-like fractal

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Mandelbox DE
float mandelbox(vec3 p, float t) {
    vec3 z = p;
    float dr = 1.0;
    float minRadius2 = 0.25;
    float fixedRadius2 = 1.0;
    float foldingLimit = 1.0;
    float scale = -2.0;
    
    for(int i = 0; i < 12; i++) {
        // Box fold
        z = clamp(z, -foldingLimit, foldingLimit) * 2.0 - z;
        
        // Sphere fold
        float r2 = dot(z, z);
        if(r2 < minRadius2) {
            float temp = (fixedRadius2 / minRadius2);
            z *= temp;
            dr *= temp;
        } else if(r2 < fixedRadius2) {
            float temp = (fixedRadius2 / r2);
            z *= temp;
            dr *= temp;
        }
        
        // Scale and translate
        z = scale * z + p;
        dr = dr * abs(scale) + 1.0;
    }
    
    return length(z) / abs(dr);
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, float t) {
    float dO = 0.0;
    
    for(int i = 0; i < 80; i++) {
        vec3 p = ro + rd * dO;
        float dS = mandelbox(p, t);
        
        dO += dS;
        if(dO > 15.0 || dS < 0.001) break;
    }
    
    return dO;
}

// Normal calculation
vec3 calcNormal(vec3 p, float t) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        mandelbox(p + e.xyy, t) - mandelbox(p - e.xyy, t),
        mandelbox(p + e.yxy, t) - mandelbox(p - e.yxy, t),
        mandelbox(p + e.yyx, t) - mandelbox(p - e.yyx, t)
    ));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    
    // Camera
    vec3 ro = vec3(cos(t * 0.3) * 4.0, sin(t * 0.2) * 2.0, sin(t * 0.3) * 4.0);
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
        
        // Color
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + length(p) * 0.2 + t * 0.5);
        
        col = col * (0.2 + 0.8 * diff) + vec3(0.5) * spec;
        
        // Fog
        col *= exp(-d * 0.08);
    } else {
        // Background
        col = vec3(0.02, 0.02, 0.05);
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
