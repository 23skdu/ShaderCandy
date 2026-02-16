#include "base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    
    // Create plasma effect with multiple sine waves
    float v = sin(centered.x * 10.0 + t);
    v += sin(centered.y * 10.0 + t * 1.2);
    v += sin((centered.x + centered.y) * 10.0 + t * 0.8);
    v += sin(length(centered) * 10.0 + t * 1.5);
    v *= 0.25;
    
    // Map to colors
    vec3 color = vec3(
        0.5 + 0.5 * sin(v * PI + t),
        0.5 + 0.5 * sin(v * PI + t + 2.0),
        0.5 + 0.5 * sin(v * PI + t + 4.0)
    );
    
    color *= intensity;
    return vec4(color, alpha);
}
