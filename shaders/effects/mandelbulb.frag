#version 450 core

#include "../base/common.glsl"

// Mandelbulb 3D Fractal

// Power function for mandelbulb
vec3 powBulb(vec3 v, float p) {
    float r = length(v);
    float theta = atan(v.y, v.x);
    float phi = acos(v.z / r);
    
    float rp = pow(r, p);
    float newTheta = theta * p;
    float newPhi = phi * p;
    
    return rp * vec3(
        sin(newPhi) * cos(newTheta),
        sin(newPhi) * sin(newTheta),
        cos(newPhi)
    );
}

// Distance estimator for Mandelbulb
float mandelbulbDE(vec3 pos, out vec4 trap) {
    vec3 z = pos;
    float dr = 1.0;
    float r = 0.0;
    float power = 8.0 + sin(time * 0.2) * 2.0; // Animated power
    
    trap = vec4(1.0);
    
    for (int i = 0; i < 6; i++) {
        r = length(z);
        if (r > 2.0) break;
        
        // Update orbit trap for coloring
        trap = min(trap, vec4(abs(z), r));
        
        // Convert to spherical coordinates
        float theta = atan(z.y, z.x);
        float phi = acos(z.z / r);
        
        // Calculate derivative
        dr = pow(r, power - 1.0) * power * dr + 1.0;
        
        // Scale and rotate the point
        float zr = pow(r, power);
        theta = theta * power;
        phi = phi * power;
        
        // Convert back to cartesian
        z = zr * vec3(
            sin(phi) * cos(theta),
            sin(phi) * sin(theta),
            cos(phi)
        );
        z += pos;
    }
    
    return 0.5 * log(r) * r / dr;
}

// Scene mapping
float map(vec3 p, out vec4 trap) {
    return mandelbulbDE(p, trap);
}

// Normal calculation
vec3 calcNormal(vec3 p) {
    vec4 trap;
    float eps = 0.001 * length(p);
    return normalize(vec3(
        map(p + vec3(eps, 0, 0), trap) - map(p - vec3(eps, 0, 0), trap),
        map(p + vec3(0, eps, 0), trap) - map(p - vec3(0, eps, 0), trap),
        map(p + vec3(0, 0, eps), trap) - map(p - vec3(0, 0, eps), trap)
    ));
}

// Ray march with adaptive stepping
float rayMarch(vec3 ro, vec3 rd, out vec4 trap) {
    float t = 0.0;
    float prevRadius = 0.0;
    float stepMultiplier = 0.9;
    
    for (int i = 0; i < 128; i++) {
        vec3 p = ro + t * rd;
        float radius = map(p, trap);
        
        if (radius < 0.001) return t;
        if (t > 20.0) break;
        
        // Adaptive step size
        float stepSize = max(radius * stepMultiplier, 0.001);
        t += stepSize;
        prevRadius = radius;
    }
    
    return -1.0;
}

// Soft shadows
float softShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
    float res = 1.0;
    float t = mint;
    vec4 trap;
    
    for (int i = 0; i < 32; i++) {
        if (t > maxt) break;
        float h = map(ro + rd * t, trap);
        if (h < 0.001) return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    
    return res;
}

// Ambient occlusion
float calcAO(vec3 p, vec3 n) {
    float occ = 0.0;
    float sca = 1.0;
    vec4 trap;
    
    for (int i = 0; i < 5; i++) {
        float h = 0.001 + 0.15 * float(i) / 4.0;
        float d = map(p + h * n, trap);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    // Camera animation
    float t = time * 0.15;
    float radius = 2.5 + sin(time * 0.1) * 0.3;
    
    vec3 ro = vec3(
        cos(t) * radius,
        sin(t * 0.3) * 0.3,
        sin(t) * radius
    );
    vec3 ta = vec3(0.0, 0.0, 0.0);
    
    // Camera matrix
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0, 1, 0)));
    vec3 vv = normalize(cross(uu, ww));
    
    // Ray direction with slight fisheye for immersion
    vec2 q = centered * (1.0 + length(centered) * 0.1);
    vec3 rd = normalize(q.x * uu + q.y * vv + 1.8 * ww);
    
    // Ray march
    vec4 trap;
    float dist = rayMarch(ro, rd, trap);
    
    // Background
    vec3 col = vec3(0.01, 0.02, 0.05);
    
    // Add stars
    float star = pow(hash(uv.x * 100.0 + uv.y * 57.0), 50.0) * 0.8;
    col += vec3(star);
    
    if (dist > 0.0) {
        vec3 pos = ro + dist * rd;
        vec3 nor = calcNormal(pos);
        
        // Lighting
        vec3 light1 = normalize(vec3(1.0, 0.8, 0.5));
        vec3 light2 = normalize(vec3(-0.5, 0.3, -0.8));
        
        // Diffuse
        float dif1 = max(dot(nor, light1), 0.0);
        float dif2 = max(dot(nor, light2), 0.0) * 0.5;
        
        // Shadows
        float shad1 = softShadow(pos + nor * 0.001, light1, 0.01, 5.0, 8.0);
        float shad2 = softShadow(pos + nor * 0.001, light2, 0.01, 5.0, 8.0);
        
        // Ambient occlusion
        float ao = calcAO(pos, nor);
        
        // Fresnel
        float fre = pow(1.0 - max(dot(nor, -rd), 0.0), 4.0);
        
        // Color based on orbit trap
        vec3 baseColor = hsv2rgb(vec3(
            trap.w * 0.1 + time * 0.05,
            0.7 + trap.y * 0.3,
            0.5 + trap.z * 0.5
        ));
        
        // Glow based on iteration count
        vec3 glowColor = hsv2rgb(vec3(
            trap.x * 0.2 + 0.6,
            0.8,
            1.0
        ));
        
        // Combine lighting
        vec3 lin = vec3(0.0);
        lin += baseColor * dif1 * shad1 * vec3(1.0, 0.9, 0.8);
        lin += baseColor * dif2 * shad2 * vec3(0.6, 0.7, 1.0);
        lin += baseColor * 0.3 * ao; // Ambient
        lin += glowColor * fre * 0.5 * ao; // Fresnel rim
        
        // Self-glow
        lin += glowColor * trap.w * 0.2;
        
        col = lin;
        
        // Fog
        float fog = exp(-dist * 0.1);
        col = mix(vec3(0.01, 0.02, 0.05), col, fog);
    }
    
    // Post-processing
    // Tone mapping
    col = col / (1.0 + col);
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    // Vignette
    col *= 1.0 - length(centered) * 0.25;
    
    // Color grading
    col = mix(col, col * vec3(1.0, 0.95, 0.9), 0.3); // Slight warm cast
    
    return vec4(col, 1.0);
}
