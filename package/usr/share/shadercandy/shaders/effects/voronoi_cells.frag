#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    float m = 1.0;
    
    // Voronoi
    for(int i = 0; i < 20; i++) {
        vec2 p = vec2(sin(t * 0.1 + i * 132.3), cos(t * 0.15 + i * 45.1));
        float d = length(centered - p);
        m = min(m, d);
    }
    
    vec3 col = vec3(clamp(1.0 - m, 0.0, 1.0));
    col = pow(col, vec3(3.0));
    col *= vec3(0.5 + 0.5 * sin(t), 0.5 + 0.5 * cos(t), 0.8);
    
    // Edges
    col += 0.5 * step(m, 0.05);
    
    col *= intensity;
    return vec4(col, alpha);
}
