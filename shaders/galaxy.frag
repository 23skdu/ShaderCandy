#version 450 core

#include "base/common.glsl"

// Galaxy - Spiral galaxy simulation

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.05;
    vec2 p = centered;
    
    // Deep space background
    vec3 col = vec3(0.005, 0.005, 0.015);
    
    // Stars background
    float stars = pow(noise(uv * 400.0), 30.0);
    stars += pow(noise(uv * 250.0 + 100.0), 25.0) * 0.7;
    col += vec3(0.9, 0.95, 1.0) * stars * 0.5;
    
    // Galaxy center
    float dist = length(p);
    float angle = atan(p.y, p.x);
    
    // Spiral arms
    float spiralArms = 2.0;
    float spiral = angle + dist * 5.0 - t;
    float armPattern = sin(spiral * spiralArms);
    
    // Galaxy brightness
    float galaxyBrightness = exp(-dist * 2.0);
    galaxyBrightness *= 0.8 + 0.2 * armPattern;
    
    // Galaxy color - blue core, purple/pink arms
    vec3 coreCol = vec3(0.8, 0.9, 1.0);
    vec3 armCol = vec3(0.6, 0.3, 0.7);
    vec3 outerCol = vec3(0.3, 0.1, 0.4);
    
    vec3 galaxyCol = mix(armCol, coreCol, exp(-dist * 3.0));
    galaxyCol = mix(outerCol, galaxyCol, smoothstep(0.5, 0.0, dist));
    
    // Apply galaxy
    col += galaxyCol * galaxyBrightness;
    
    // Star clusters along arms
    float cluster = pow(noise(vec2(spiral * 2.0, dist * 10.0)), 10.0);
    col += vec3(1.0, 0.95, 0.9) * cluster * galaxyBrightness * 2.0;
    
    // Central bulge
    float bulge = exp(-dist * 5.0);
    col += vec3(1.0, 0.9, 0.7) * bulge * 0.5;
    
    // Supermassive black hole at center
    float bh = smoothstep(0.02, 0.0, dist);
    col = mix(col, vec3(0.0), bh);
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
