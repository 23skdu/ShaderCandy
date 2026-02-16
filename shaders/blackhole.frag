#version 450 core

#include "base/common.glsl"

// Blackhole - Black hole with accretion disk

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Gravitational lensing approximation
vec2 blackholeLensing(vec2 uv, vec2 bhPos, float bhRadius) {
    vec2 delta = uv - bhPos;
    float dist = length(delta);
    
    // Lensing strength falls off with distance
    float lensing = bhRadius * bhRadius / (dist * dist + 0.001);
    lensing = min(lensing, 0.5); // Cap the effect
    
    return uv - normalize(delta) * lensing * 0.1;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    vec2 p = centered;
    
    // Black hole position
    vec2 bhPos = vec2(0.0, 0.0);
    float bhRadius = 0.15;
    
    // Apply gravitational lensing
    vec2 lensedUV = blackholeLensing(uv, vec2(0.5, 0.5), bhRadius);
    vec2 lensedP = lensedUV * 2.0 - 1.0;
    lensedP.x *= resolution.x / resolution.y;
    
    // Starfield background
    vec3 col = vec3(0.0);
    float stars = pow(noise(lensedUV * 400.0), 30.0);
    col += vec3(0.9, 0.95, 1.0) * stars;
    
    // Accretion disk
    float dist = length(p - bhPos);
    
    // Disk inner and outer radius
    float diskInner = bhRadius * 1.5;
    float diskOuter = bhRadius * 4.0;
    
    if(dist > diskInner && dist < diskOuter) {
        // Angle for disk texture
        float angle = atan(p.y - bhPos.y, p.x - bhPos.x);
        
        // Rotating disk
        float diskAngle = angle + t * 2.0;
        
        // Disk pattern
        float diskPattern = sin(diskAngle * 10.0 + dist * 20.0);
        diskPattern += sin(diskAngle * 20.0 - t * 3.0) * 0.5;
        
        // Disk color - hot inner, cooler outer
        float temp = 1.0 - (dist - diskInner) / (diskOuter - diskInner);
        vec3 diskCol = mix(vec3(1.0, 0.8, 0.3), vec3(0.8, 0.3, 0.1), temp);
        diskCol = mix(vec3(0.5, 0.2, 0.8), diskCol, temp * temp);
        
        // Apply pattern
        float diskIntensity = smoothstep(diskOuter, diskInner, dist) * 
                              smoothstep(diskInner * 0.9, diskInner, dist);
        diskIntensity *= 0.7 + 0.3 * diskPattern;
        
        col += diskCol * diskIntensity;
    }
    
    // Black hole event horizon
    float bh = smoothstep(bhRadius, bhRadius * 0.95, dist);
    col = mix(col, vec3(0.0), bh);
    
    // Photon ring (bright ring around black hole)
    float photonRing = smoothstep(bhRadius * 1.1, bhRadius * 1.05, dist) -
                       smoothstep(bhRadius * 1.2, bhRadius * 1.1, dist);
    col += vec3(1.0, 0.9, 0.7) * photonRing * 2.0;
    
    // Doppler beaming effect (brighter on one side)
    float doppler = smoothstep(0.0, 0.5, p.x - bhPos.x);
    col *= 0.7 + 0.3 * doppler;
    
    col *= intensity;
    return vec4(col, alpha);
}
