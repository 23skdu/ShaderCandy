#include "base/common.glsl"

// chrono_warp - Bending space-time grid with trail effects

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Warp UVs
    float r = length(p);
    float a = atan(p.y, p.x);
    a += 0.5 * sin(r * 3.0 - t);
    vec2 wuv = vec2(cos(a), sin(a)) * r;
    
    vec3 color = vec3(0.0);
    
    // Grid layers
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        float scale = 4.0 + fi * 2.0;
        vec2 gv = fract(wuv * scale + t * 0.2 * (fi + 1.0)) - 0.5;
        float dist = length(gv);
        float line = smoothstep(0.48, 0.45, abs(gv.x)) + smoothstep(0.48, 0.45, abs(gv.y));
        
        vec3 layerColor = hsv2rgb(vec3(fract(t * 0.1 + fi * 0.3), 0.7, 1.0));
        color += layerColor * line * exp(-r * 2.0) * (0.5 / (fi + 1.0));
    }
    
    // Core pulse
    color += hsv2rgb(vec3(fract(t * 0.5), 0.8, 1.0)) * (0.1 / (r + 0.01));
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.4;
    color *= vig;
    
    color *= intensity;
    return vec4(color, alpha);
}