#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    
    // Animate the Julia constant
    vec2 c = vec2(0.355 + 0.1 * sin(t), 0.355 + 0.1 * cos(t * 0.7));
    if (mouseButtons > 0.0) {
        c = mouse * 2.0 - 1.0;
    }
    
    vec2 z = centered * 1.5;
    float iter = 0.0;
    float max_iter = 128.0;
    
    for (int i = 0; i < 128; i++) {
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (length(z) > 4.0) break;
        iter += 1.0;
    }
    
    vec3 color = vec3(0.0);
    if (iter < max_iter) {
        float dist = length(z);
        float smooth_iter = iter - log2(log(dist + 0.001) / log(2.0));
        color = 0.5 + 0.5 * sin(vec3(0.1, 0.2, 0.3) * smooth_iter + t);
    }
    
    color *= intensity;
    return vec4(color, alpha);
}
