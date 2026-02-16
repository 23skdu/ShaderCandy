#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec3 color = vec3(0.0);
    float r = length(centered);
    float a = atan(centered.y, centered.x);
    
    for(float i = 0.0; i < 3.0; i++) {
        float f = t + i * 2.0;
        float s = sin(f) * 0.5 + 0.5;
        float w = 0.02 / abs(sin(r * 10.0 + t * 2.0 + i) + sin(a * 5.0 + t) * 0.5);
        color += vec3(s, fract(s + 0.3), fract(s + 0.6)) * w;
    }
    
    color *= intensity;
    return vec4(color, alpha);
}
