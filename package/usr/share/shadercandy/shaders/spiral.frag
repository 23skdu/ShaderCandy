#include "base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    
    // Polar coordinates
    float angle = atan(centered.y, centered.x);
    float radius = length(centered);
    
    // Create spiral
    float spiral_val = angle / PI + log(radius + 0.1) * 3.0 - t;
    spiral_val = fract(spiral_val);
    
    // Add some variation
    float pattern = smoothstep(0.3, 0.7, spiral_val);
    
    // Color based on radius and angle
    vec3 color = vec3(
        0.5 + 0.5 * sin(radius * 5.0 + t),
        0.5 + 0.5 * sin(angle * 2.0 + t * 0.7),
        0.5 + 0.5 * sin(pattern * TWO_PI + t * 1.2)
    );
    
    // Brighten the spiral arms
    color *= 0.5 + pattern * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}
