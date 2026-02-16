#include "../base/common.glsl"

// Simple bloom approximation effect
vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    // Create bright spots
    float brightness = 0.0;
    vec3 col = vec3(0.0);
    
    // Add some glowing orbs
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 pos = vec2(
            sin(t * 0.3 + fi * 1.5) * 0.7,
            cos(t * 0.2 + fi * 2.1) * 0.5
        );
        float d = length(centered - pos);
        float glow = 0.02 / (d + 0.02);
        
        vec3 orbCol = vec3(
            0.5 + 0.5 * sin(fi + t),
            0.5 + 0.5 * sin(fi + t + 2.0),
            0.5 + 0.5 * sin(fi + t + 4.0)
        );
        
        col += orbCol * glow;
    }
    
    // Add background gradient
    col += vec3(0.05, 0.05, 0.1) * (1.0 - length(centered) * 0.5);
    
    col *= intensity;
    return vec4(col, alpha);
}
