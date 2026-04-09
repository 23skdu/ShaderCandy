#version 450 core

#include "base/common.glsl"

// Plasma - Classic demo scene plasma effect

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    vec2 p = uv * 10.0;
    
    // Multiple sine waves at different frequencies
    float v1 = sin(p.x * 0.5 + t);
    float v2 = sin(p.y * 0.3 + t * 0.7);
    float v3 = sin((p.x + p.y) * 0.4 + t * 1.2);
    float v4 = sin(sqrt(p.x * p.x + p.y * p.y) * 0.8 - t * 0.5);
    
    // Combine waves
    float plasma = (v1 + v2 + v3 + v4) * 0.25;
    
    // Add more detail
    float v5 = sin(p.x * 1.2 + t * 2.0) * cos(p.y * 0.8 + t * 1.5);
    float v6 = sin(p.y * 1.5 - t * 1.8) * cos(p.x * 0.6 + t);
    plasma += (v5 + v6) * 0.1;
    
    // Map to color
    vec3 col = vec3(
        0.5 + 0.5 * sin(plasma * 3.14159 + 0.0),
        0.5 + 0.5 * sin(plasma * 3.14159 + 2.094),
        0.5 + 0.5 * sin(plasma * 3.14159 + 4.188)
    );
    
    // Enhance contrast
    col = pow(col, vec3(0.8));
    
    col *= intensity;
    return vec4(col, alpha);
}
