#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = vec2(atan(centered.y, centered.x) / PI, 0.5 / length(centered)) + t * 0.1;
    p.y += p.x * 2.0;
    
    // Grid pattern
    vec2 grid = fract(p * 5.0) - 0.5;
    float d = length(max(abs(grid) - 0.2, 0.0));
    
    vec3 col = vec3(0.0);
    
    // Kaleidoscopic colors
    vec3 c1 = vec3(0.5 + 0.5 * sin(t), 0.5 + 0.5 * cos(t * 0.5), 0.5);
    vec3 c2 = vec3(0.5 + 0.5 * sin(t * 1.5 + 2.0), 0.5 + 0.5 * cos(t + 4.0), 1.0);
    
    float mask = smoothstep(0.1, 0.0, d);
    col = mix(c1, c2, mask * sin(centered.x * 10.0 + t));
    
    // Add glow
    col += vec3(0.1, 0.2, 1.0) / length(centered) * 0.2;
    
    col *= intensity;
    return vec4(col, alpha);
}
