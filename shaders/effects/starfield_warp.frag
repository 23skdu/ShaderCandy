#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec3 col = vec3(0.0);
    
    // Starfield
    for(float i = 0.0; i < 100.0; i++) {
        float z = fract(i * 0.0123 - t * 0.5);
        float fade = 1.0 - z;
        
        vec2 st = centered * (0.5 / z);
        float a = atan(st.y, st.x) + z * 5.0;
        float r = length(st);
        
        vec2 pos = vec2(sin(i * 123.4 + a), cos(i * 456.7 + a)) * r;
        
        float d = length(st - pos);
        float size = 0.005 / z;
        
        col += vec3(1.0, 0.8, 0.5) * fade * max(0.0, 1.0 - d / size) * step(d, size);
    }
    
    // Background nebula
    col += vec3(0.1, 0.0, 0.2) * (0.5 + 0.5 * sin(centered.y * 5.0 + t));
    
    col *= intensity;
    return vec4(col, alpha);
}
