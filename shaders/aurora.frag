#version 450 core

#include "base/common.glsl"

// Aurora - Northern lights simulation

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    vec2 p = centered;
    
    // Night sky gradient
    vec3 col = mix(vec3(0.0, 0.02, 0.08), vec3(0.02, 0.05, 0.15), uv.y);
    
    // Stars
    float stars = pow(noise(uv * 300.0), 25.0);
    float stars2 = pow(noise(uv * 200.0 + 50.0), 20.0) * 0.7;
    col += vec3(0.9, 0.95, 1.0) * (stars + stars2);
    
    // Aurora bands
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        
        // Aurora position and movement
        vec2 auroraUV = p;
        auroraUV.x += t * (0.2 + fi * 0.05);
        auroraUV.y += fi * 0.3 - 0.3;
        
        // Wavy aurora shape
        float wave = sin(auroraUV.x * 2.0 + t * 0.5 + fi) * 0.3;
        wave += sin(auroraUV.x * 5.0 - t * 0.3) * 0.1;
        
        // Aurora intensity
        float aurora = smoothstep(0.3, 0.0, abs(auroraUV.y - wave));
        aurora *= smoothstep(1.5, 0.0, abs(auroraUV.x));
        
        // Aurora color - green and purple hues
        vec3 auroraCol1 = vec3(0.2, 0.9, 0.4); // Green
        vec3 auroraCol2 = vec3(0.6, 0.2, 0.9); // Purple
        vec3 auroraCol = mix(auroraCol1, auroraCol2, sin(t * 0.5 + fi) * 0.5 + 0.5);
        
        // Add aurora glow
        col += auroraCol * aurora * 0.4;
    }
    
    // Ground silhouette
    float ground = step(-0.6, p.y) * (1.0 - step(-0.55, p.y));
    col = mix(col, vec3(0.0, 0.02, 0.05), ground);
    
    // Reflection on ground
    float reflection = smoothstep(-0.55, -0.6, p.y);
    col += vec3(0.1, 0.4, 0.2) * reflection * 0.2;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
