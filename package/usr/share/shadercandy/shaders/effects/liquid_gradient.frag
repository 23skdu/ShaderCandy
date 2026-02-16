#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec3 col = vec3(0.0);
    
    // Smooth plasma
    for(float i = 1.0; i < 4.0; i++) {
        centered.x += 0.3 / i * sin(i * 3.0 * centered.y + t);
        centered.y += 0.3 / i * cos(i * 3.0 * centered.x + t);
        float d = length(centered - vec2(sin(t * 0.3) * 0.5, cos(t * 0.2) * 0.5));
        
        col.r = sin(d * 10.0 + t + 1.0);
        col.g = sin(d * 10.0 + t + 2.0);
        col.b = sin(d * 10.0 + t + 3.0);
    }
    
    col = col * 0.5 + 0.5;
    
    col *= intensity;
    return vec4(col, alpha);
}
