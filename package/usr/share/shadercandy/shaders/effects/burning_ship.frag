#version 450 core

#include "base/common.glsl"

// Burning Ship Fractal - Modified Mandelbrot with absolute values

vec2 burningShip(vec2 c) {
    vec2 z = vec2(0.0);
    vec2 dz = vec2(0.0);
    float n = 0.0;
    
    for(int i = 0; i < 100; i++) {
        // Derivative
        dz = 2.0 * vec2(z.x * dz.x - z.y * dz.y, z.x * dz.y + z.y * dz.x) + vec2(1.0, 0.0);
        
        // z = z^2 + c with absolute values (the "ship" part)
        float x = (z.x * z.x - z.y * z.y) + c.x;
        float y = abs(2.0 * z.x * z.y) + c.y;
        z = vec2(x, y);
        
        n += 1.0;
        if(dot(z, z) > 256.0) break;
    }
    
    float d = 0.5 * log(dot(z, z)) * sqrt(dot(z, z) / dot(dz, dz));
    return vec2(d, n);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = centered * 2.0;
    
    // Offset to show the ship shape
    vec2 c = p - vec2(0.5, 0.0);
    
    float t = time * 0.1;
    
    // Animate the fractal slightly
    c += vec2(0.05 * sin(t), 0.03 * cos(t));
    
    vec2 d = burningShip(c);
    
    vec3 col;
    if(d.x < 0.001) {
        col = vec3(0.0); // Inside - dark
    } else {
        // Outside - color based on iterations
        float n = d.y / 100.0;
        float s = pow(d.x, 0.3);
        
        col = vec3(
            0.5 + 0.5 * cos(3.0 + n * 10.0 + 0.0),
            0.5 + 0.5 * cos(3.0 + n * 10.0 + 2.0),
            0.5 + 0.5 * cos(3.0 + n * 10.0 + 4.0)
        );
        
        // Add glow
        col *= s * 2.0;
    }
    
    // Add scanlines
    col *= 0.9 + 0.1 * sin(uv.y * resolution.y);
    
    return vec4(col * intensity, 1.0);
}
