#version 450 core

#include "base/common.glsl"

// Lissajous - Lissajous curves

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    vec2 p = centered;
    
    // Dark background
    vec3 col = vec3(0.02, 0.02, 0.05);
    
    // Multiple Lissajous curves
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        
        // Lissajous parameters
        float a = 3.0 + fi * 0.5;
        float b = 4.0 + fi * 0.3;
        float delta = fi * 0.5;
        
        // Draw the curve as many points
        for(float j = 0.0; j < 200.0; j++) {
            float theta = j / 200.0 * TWO_PI;
            
            // Lissajous equations
            float x = sin(a * theta + delta + t * (1.0 + fi * 0.2)) * (0.6 - fi * 0.1);
            float y = sin(b * theta + t * (1.0 + fi * 0.1)) * (0.6 - fi * 0.1);
            
            // Distance to point
            float dist = length(p - vec2(x, y));
            
            // Curve color
            vec3 curveCol = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + fi * 0.5 + t);
            
            // Add to color
            col += curveCol * smoothstep(0.02, 0.0, dist) * 0.5;
        }
    }
    
    // Add glow
    col += vec3(0.1, 0.3, 0.5) * 0.2;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
