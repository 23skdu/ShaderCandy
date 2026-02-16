#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    // Zoom
    float zoom = 1.0 + t * 0.1;
    vec2 center = vec2(-0.745, 0.186);
    
    // Animate center a bit
    center += vec2(sin(t * 0.1) * 0.01, cos(t * 0.13) * 0.01);
    
    vec2 c = center + centered / pow(2.0, zoom);
    vec2 z = c;
    
    int iter = 0;
    const int max_iter = 100;
    
    for(int i = 0; i < max_iter; i++) {
        if(length(z) > 2.0) break;
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        iter++;
    }
    
    vec3 col = vec3(0.0);
    if (iter < max_iter) {
        float fIter = float(iter) / float(max_iter);
        col = vec3(sin(fIter * 10.0 + t), sin(fIter * 15.0 + t * 1.5), sin(fIter * 20.0 + t * 2.0));
        col = col * 0.5 + 0.5;
    }
    
    col *= intensity;
    return vec4(col, alpha);
}
