#include "base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 gridUV = uv * 20.0; // Scale up for more squares
    float t = time * speed * 0.3;
    
    // Create checkerboard pattern
    vec2 grid = floor(gridUV);
    float checker = mod(grid.x + grid.y, 2.0);
    
    // Animate the colors
    vec3 color1 = vec3(
        0.5 + 0.5 * sin(t),
        0.5 + 0.5 * sin(t + 2.0),
        0.5 + 0.5 * sin(t + 4.0)
    );
    
    vec3 color2 = vec3(
        0.5 + 0.5 * sin(t + 3.0),
        0.5 + 0.5 * sin(t + 5.0),
        0.5 + 0.5 * sin(t + 1.0)
    );
    
    // Mix colors based on checker pattern
    vec3 color = mix(color1, color2, checker);
    
    // Add some shimmer
    float shimmer = sin(grid.x * 0.5 + grid.y * 0.5 + t * 2.0) * 0.1 + 0.9;
    color *= shimmer;
    
    color *= intensity;
    return vec4(color, alpha);
}
