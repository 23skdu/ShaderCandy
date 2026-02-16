#version 450 core

#include "../base/common.glsl"

// Nebula Cloud - Particle-like volumetric effect using noise

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Volume rendering of nebula
float nebula(vec3 p) {
    float t = time * 0.1;
    
    // Domain warp for organic movement
    vec3 q = p;
    q.x += fbm(p + t, 3) * 0.5;
    q.y += fbm(p + t + 100.0, 3) * 0.5;
    q.z += fbm(p + t + 200.0, 3) * 0.5;
    
    // Multiple layers of FBM for cloud density
    float density = 0.0;
    float amp = 0.5;
    vec3 offset = vec3(t * 0.2, t * 0.1, t * 0.15);
    
    for (int i = 0; i < 5; i++) {
        density += amp * snoise(q * (1.0 + float(i) * 0.5) + offset);
        q = q * 2.0 + offset;
        amp *= 0.5;
    }
    
    // Create swirling arms
    float angle = atan(p.z, p.x);
    float radius = length(p.xz);
    float spiral = sin(angle * 3.0 + radius * 2.0 - t);
    density += spiral * 0.2 * exp(-radius * 0.5);
    
    return max(density, 0.0);
}

// Star field
float stars(vec3 rd) {
    float s = 0.0;
    vec3 p = rd * 100.0;
    
    for (int i = 0; i < 3; i++) {
        vec3 grid = floor(p);
        float h = hash(grid.x + grid.y * 57.0 + grid.z * 113.0 + float(i) * 437.0);
        if (h > 0.98) {
            float size = hash(grid.x * 2.0) * 0.5 + 0.5;
            float twinkle = sin(time * 2.0 + h * 10.0) * 0.5 + 0.5;
            s += twinkle * size * smoothstep(0.02, 0.0, length(fract(p) - 0.5));
        }
        p *= 1.5;
    }
    
    return s;
}

// Ray march through volume
vec4 rayMarchVolume(vec3 ro, vec3 rd) {
    vec4 col = vec4(0.0);
    float t = 0.5;
    
    // Color palette for nebula
    vec3 col1 = vec3(0.1, 0.0, 0.3);  // Deep purple
    vec3 col2 = vec3(0.0, 0.2, 0.5);  // Blue
    vec3 col3 = vec3(0.0, 0.6, 0.7);  // Cyan
    vec3 col4 = vec3(0.8, 0.3, 0.1);  // Orange
    vec3 col5 = vec3(1.0, 0.9, 0.7);  // White/yellow core
    
    for (int i = 0; i < 64; i++) {
        if (col.a > 0.99) break;
        
        vec3 p = ro + t * rd;
        float d = nebula(p);
        
        if (d > 0.01) {
            // Color based on density and position
            float hue = d * 0.5 + length(p) * 0.1;
            vec3 sampleCol = mix(col1, col2, smoothstep(0.0, 0.3, hue));
            sampleCol = mix(sampleCol, col3, smoothstep(0.3, 0.5, hue));
            sampleCol = mix(sampleCol, col4, smoothstep(0.5, 0.7, hue));
            sampleCol = mix(sampleCol, col5, smoothstep(0.7, 1.0, d));
            
            // Density attenuation
            d *= 0.1;
            
            // Accumulate color with alpha blending
            col.rgb += (1.0 - col.a) * sampleCol * d;
            col.a += (1.0 - col.a) * d;
        }
        
        // Step size increases with distance
        t += 0.02 + t * 0.01;
    }
    
    return col;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    // Camera setup - slowly rotating around center
    float t = time * 0.1;
    float camRadius = 4.0 + sin(time * 0.2) * 0.5;
    
    vec3 ro = vec3(
        cos(t) * camRadius,
        sin(t * 0.5) * 0.5,
        sin(t) * camRadius
    );
    vec3 ta = vec3(0.0, 0.0, 0.0);
    
    // Camera matrix
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0, 1, 0)));
    vec3 vv = normalize(cross(uu, ww));
    
    // Ray direction
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Background stars
    vec3 col = vec3(0.0);
    col += vec3(0.8, 0.9, 1.0) * stars(rd) * 0.5;
    
    // Nebula volume
    vec4 vol = rayMarchVolume(ro, rd);
    col = mix(col, vol.rgb, vol.a);
    
    // Add bright core glow
    float core = max(0.0, snoise(rd * 3.0 + time * 0.05));
    col += vec3(1.0, 0.9, 0.7) * core * core * 0.3;
    
    // Post-processing
    // Tone mapping
    col = col / (1.0 + col);
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    // Vignette
    col *= 1.0 - length(centered) * 0.2;
    
    // Subtle film grain
    col += (hash(uv.x + uv.y * 57.0 + time) - 0.5) * 0.02;
    
    return vec4(col, 1.0);
}
