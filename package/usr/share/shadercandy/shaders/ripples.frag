#include "base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    // Distance from center
    float dist = length(centered);
    
    // Create ripple effect
    float ripple = sin(dist * 20.0 - t * 3.0) * 0.5 + 0.5;
    ripple *= 1.0 / (1.0 + dist * 2.0); // Fade with distance
    
    // Add secondary ripples
    float ripple2 = sin(dist * 15.0 - t * 2.0 + 1.0) * 0.5 + 0.5;
    ripple2 *= 1.0 / (1.0 + dist * 3.0);
    
    // Combine ripples
    float combined = ripple + ripple2 * 0.5;
    
    // Color based on ripple intensity
    vec3 color = vec3(
        0.2 + combined * 0.8,
        0.4 + combined * 0.6 * sin(t * 0.5),
        0.6 + combined * 0.4 * cos(t * 0.3)
    );
    
    color *= intensity;
    return vec4(color, alpha);
}
