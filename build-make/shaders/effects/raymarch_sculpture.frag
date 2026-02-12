#version 450 core

#include "../base/common.glsl"

// Ray marching with SDF - Abstract geometric sculpture

// Distance to scene
float map(vec3 p) {
    // Time-based rotation
    float t = time * 0.3;
    
    // Main sphere with holes
    vec3 q = rotateY(p, t);
    q = rotateX(q, t * 0.5);
    
    float d1 = sdSphere(q, 1.5);
    
    // Create holes using boolean operations
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * TWO_PI / 6.0 + t;
        vec3 holePos = vec3(cos(angle), sin(angle * 0.5), sin(angle)) * 0.8;
        d1 = opSubtraction(sdSphere(q - holePos, 0.4), d1);
    }
    
    // Outer torus rings
    vec3 q2 = rotateZ(p, t * 0.7);
    q2 = rotateY(q2, t * 0.3);
    float d2 = sdTorus(q2, vec2(2.2, 0.15));
    
    float d3 = sdTorus(rotateX(p, t * 0.5 + PI/3.0), vec2(2.0, 0.1));
    
    // Combine everything
    float d = opSmoothUnion(d1, d2, 0.2);
    d = opSmoothUnion(d, d3, 0.15);
    
    // Add floating particles
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec3 particlePos = vec3(
            sin(time * 0.5 + fi) * (2.5 + fi * 0.3),
            cos(time * 0.3 + fi * 1.3) * (2.0 + fi * 0.2),
            sin(time * 0.4 + fi * 0.7) * (2.5 + fi * 0.3)
        );
        d = opSmoothUnion(d, sdSphere(p - particlePos, 0.1 + fi * 0.05), 0.1);
    }
    
    return d;
}

// Calculate normal using gradient
vec3 calcNormal(vec3 p) {
    float eps = 0.001;
    return normalize(vec3(
        map(p + vec3(eps, 0, 0)) - map(p - vec3(eps, 0, 0)),
        map(p + vec3(0, eps, 0)) - map(p - vec3(0, eps, 0)),
        map(p + vec3(0, 0, eps)) - map(p - vec3(0, 0, eps))
    ));
}

// Ray march
float rayMarch(vec3 ro, vec3 rd) {
    float t = 0.0;
    for (int i = 0; i < 100; i++) {
        vec3 p = ro + t * rd;
        float d = map(p);
        if (d < 0.001 || t > 50.0) break;
        t += d;
    }
    return t;
}

// Soft shadow
float softShadow(vec3 ro, vec3 rd, float k) {
    float res = 1.0;
    float t = 0.1;
    for (int i = 0; i < 32; i++) {
        float h = map(ro + rd * t);
        res = min(res, k * h / t);
        t += clamp(h, 0.01, 0.5);
        if (res < 0.001 || t > 20.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

// Ambient occlusion
float calcAO(vec3 p, vec3 n) {
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = map(p + h * n);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    // Camera setup
    float t = time * 0.2;
    vec3 ro = vec3(
        sin(t) * 4.0,
        sin(t * 0.5) * 1.0 + 0.5,
        cos(t) * 4.0
    );
    vec3 ta = vec3(0.0, 0.0, 0.0);
    
    // Camera matrix
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0, 1, 0)));
    vec3 vv = normalize(cross(uu, ww));
    
    // Ray direction
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Ray march
    float dist = rayMarch(ro, rd);
    
    // Background
    vec3 col = vec3(0.02, 0.02, 0.05);
    
    if (dist < 50.0) {
        vec3 pos = ro + dist * rd;
        vec3 nor = calcNormal(pos);
        
        // Lighting
        vec3 lightPos = vec3(5.0, 8.0, 5.0);
        vec3 lig = normalize(lightPos - pos);
        
        // Diffuse
        float dif = max(dot(nor, lig), 0.0);
        
        // Specular
        vec3 ref = reflect(-lig, nor);
        float spec = pow(max(dot(ref, -rd), 0.0), 32.0);
        
        // Shadow
        float shad = softShadow(pos + nor * 0.01, lig, 8.0);
        
        // Ambient occlusion
        float ao = calcAO(pos, nor);
        
        // Fresnel
        float fre = pow(1.0 - max(dot(nor, -rd), 0.0), 3.0);
        
        // Material color - iridescent
        float hue = length(pos) * 0.2 + time * 0.1;
        vec3 matCol = hsv2rgb(vec3(fract(hue), 0.8, 1.0));
        
        // Combine
        col = matCol * dif * shad;
        col += vec3(0.5) * spec * shad;
        col += matCol * fre * 0.5;
        col *= ao;
        
        // Fog
        float fog = exp(-dist * 0.05);
        col = mix(vec3(0.02, 0.02, 0.05), col, fog);
    }
    
    // Post-processing
    col = pow(col, vec3(0.4545)); // Gamma correction
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col, 1.0);
}
