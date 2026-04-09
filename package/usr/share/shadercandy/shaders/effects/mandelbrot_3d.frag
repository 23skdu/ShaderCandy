#version 450 core

#include "base/common.glsl"

// Mandelbrot 3D - 3D Mandelbrot set visualization

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// 3D Mandelbrot DE (based on "Mandelbulb" concept but with standard z^2+c)
float mandelbrot3D(vec3 p) {
    vec3 z = p;
    float dr = 1.0;
    float r = 0.0;
    
    for(int i = 0; i < 10; i++) {
        r = length(z);
        if(r > 4.0) break;
        
        // Convert to spherical
        float theta = acos(clamp(z.z / r, -1.0, 1.0));
        float phi = atan(z.y, z.x);
        
        dr = pow(r, 2.0) * 2.0 * dr + 1.0;
        
        // z = z^2 + c
        float zr = r * r;
        theta = theta * 2.0;
        phi = phi * 2.0;
        
        z = zr * vec3(
            sin(theta) * cos(phi),
            sin(phi) * sin(theta),
            cos(theta)
        );
        z += p;
    }
    
    return 0.5 * log(r) * r / dr;
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd) {
    float dO = 0.0;
    
    for(int i = 0; i < 80; i++) {
        vec3 p = ro + rd * dO;
        float dS = mandelbrot3D(p);
        
        dO += dS;
        if(dO > 10.0 || dS < 0.001) break;
    }
    
    return dO;
}

// Normal calculation
vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        mandelbrot3D(p + e.xyy) - mandelbrot3D(p - e.xyy),
        mandelbrot3D(p + e.yxy) - mandelbrot3D(p - e.yxy),
        mandelbrot3D(p + e.yyx) - mandelbrot3D(p - e.yyx)
    ));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    
    // Camera
    vec3 ro = vec3(cos(t * 0.3) * 3.0, sin(t * 0.2) * 1.5, sin(t * 0.3) * 3.0);
    vec3 ta = vec3(0.0);
    
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Ray march
    float d = rayMarch(ro, rd);
    
    vec3 col = vec3(0.0);
    
    if(d < 10.0) {
        vec3 p = ro + rd * d;
        vec3 n = calcNormal(p);
        
        // Lighting
        vec3 lightDir = normalize(vec3(1.0, 2.0, 1.0));
        float diff = max(dot(n, lightDir), 0.0);
        float spec = pow(max(dot(reflect(-lightDir, n), -rd), 0.0), 32.0);
        
        // Color based on position
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + length(p) * 0.3 + t);
        
        col = col * (0.2 + 0.8 * diff) + vec3(0.5) * spec;
        
        // Fog
        col *= exp(-d * 0.1);
    } else {
        // Background
        col = vec3(0.01, 0.01, 0.03);
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
