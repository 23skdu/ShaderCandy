#include "base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    
    // Convert to polar coordinates
    float angle = atan(centered.y, centered.x);
    float radius = length(centered);
    
    // Create tunnel effect with safety epsilon
    float tunnel = 0.1 / (radius + 0.001);
    float rotation = angle / PI + t;
    
    // Stripe pattern
    float stripes = sin(tunnel * 10.0 - t * 2.0) * 0.5 + 0.5;
    float spiral = sin(rotation * 8.0 + tunnel * 5.0) * 0.5 + 0.5;
    
    // Combine patterns
    float pattern = stripes * spiral;
    
    // Color gradient based on angle and depth
    vec3 color = vec3(
        0.5 + 0.5 * sin(pattern * TWO_PI + t),
        0.5 + 0.5 * sin(pattern * TWO_PI + t + 2.0),
        0.5 + 0.5 * sin(pattern * TWO_PI + t + 4.0)
    );
    
    // Add glow at center
    color += vec3(0.2, 0.1, 0.3) * (1.0 - smoothstep(0.0, 0.5, radius));
    
    color *= intensity;
    return vec4(color, alpha);
}
