#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    
    // Zoom in on an interesting coordinate
    float zoom = pow(2.0, 1.0 + 5.0 * (0.5 + 0.5 * sin(t * 0.5)));
    vec2 center = vec2(-0.74364388703, 0.13182590421);
    vec2 c = center + centered / zoom;
    
    vec2 z = vec2(0.0);
    float iter = 0.0;
    float max_iter = 256.0;
    
    for (int i = 0; i < 256; i++) {
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (length(z) > 100.0) break;
        iter += 1.0;
    }
    
    vec3 color = vec3(0.0);
    if (iter < max_iter) {
        float dist = length(z);
        float smooth_iter = iter - log2(log(dist) / log(100.0));
        
        color = 0.5 + 0.5 * sin(vec3(0.05, 0.1, 0.15) * smooth_iter + t * 2.0);
        color = pow(color, vec3(1.2));
    }
    
    color *= intensity;
    return vec4(color, alpha);
}
