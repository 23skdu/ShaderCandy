#version 450 core

#include "base/common.glsl"

// Sierpinski - Sierpinski triangle/gasket fractal

// Distance to Sierpinski triangle
float sierpinski(vec2 p, int iterations) {
    float scale = 1.0;
    
    for(int i = 0; i < iterations; i++) {
        // Fold coordinates
        p.x = abs(p.x);
        
        // Rotate and scale
        float c = 0.5;
        float s = sqrt(3.0) * 0.5;
        
        if(p.x + s * p.y > 0.0) {
            vec2 tmp = p;
            p.x = c * tmp.x - s * tmp.y;
            p.y = s * tmp.x + c * tmp.y;
        }
        
        p.x -= c;
        p.y -= s;
        
        scale *= 2.0;
        p *= 2.0;
    }
    
    return length(p) / scale;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    
    // Scale and position
    vec2 p = centered * 2.5;
    
    // Rotate
    float c = cos(t * 0.2);
    float s = sin(t * 0.2);
    p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
    
    // Calculate distance to Sierpinski
    float d = sierpinski(p, 12);
    
    vec3 col;
    
    if(d < 0.01) {
        // Inside triangle - color based on depth
        float depth = -log(d + 0.001) * 0.1;
        col = 0.5 + 0.5 * cos(vec3(0.0, 0.5, 1.0) + depth + t);
        col = mix(vec3(0.1), col, smoothstep(0.0, 0.01, d));
    } else {
        // Outside - gradient
        col = vec3(0.02, 0.02, 0.05);
    }
    
    // Add edge glow
    float edge = smoothstep(0.02, 0.0, d);
    col += vec3(0.5, 0.7, 1.0) * edge * 0.5;
    
    // Background gradient
    col += vec3(0.0, 0.05, 0.1) * (1.0 - edge);
    
    return vec4(col * intensity, alpha);
}
