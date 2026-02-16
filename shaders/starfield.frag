#version 450 core

#include "base/common.glsl"

// Starfield - Parallax starfield with twinkling stars

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = centered;
    float t = time * speed * 0.15;
    
    // Deep space
    vec3 color = vec3(0.01, 0.01, 0.02);
    
    // Multiple star layers with parallax
    for (float layer = 0.0; layer < 4.0; layer++) {
        float layerSpeed = 0.2 + layer * 0.15;
        float scale = 100.0 + layer * 50.0;
        float brightness = 1.0 - layer * 0.2;
        
        // Stars at this layer
        float stars = pow(noise(p * scale + vec2(t * layerSpeed, 0.0)), 30.0 - layer * 5.0);
        
        // Twinkle
        float twinkle = sin(t * (3.0 + layer) + p.x * 50.0 + p.y * 30.0) * 0.4 + 0.6;
        stars *= twinkle;
        
        color += vec3(brightness) * stars;
    }
    
    // Bright stars with glow
    float brightStars = pow(noise(p * 80.0 + vec2(t * 0.1, 0.0)), 35.0);
    if (brightStars > 0.5) {
        float glow = smoothstep(0.5, 1.0, brightStars);
        color += vec3(1.0, 0.95, 0.9) * glow;
        
        // Color variation for some stars
        float colorVar = noise(p * 50.0);
        if (colorVar > 0.7) {
            color += vec3(0.3, 0.5, 1.0) * glow * 0.5; // Blue star
        } else if (colorVar > 0.5) {
            color += vec3(1.0, 0.7, 0.4) * glow * 0.5; // Orange star
        }
    }
    
    // Distant nebula glow
    float nebula = fbm(vec3(p * 2.0, t * 0.05), 3) * 0.15;
    color += vec3(0.3, 0.2, 0.4) * nebula;
    
    color *= intensity;
    return vec4(color, alpha);
}
