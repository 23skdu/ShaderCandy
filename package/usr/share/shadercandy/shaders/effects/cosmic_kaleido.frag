#include "base/common.glsl"

// cosmic_kaleido - 3D kaleidoscopic spherical projection

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
    
    // Polar coordinates
    float r = length(p);
    float a = atan(p.y, p.x);
    
    // Kaleidoscope split
    float sides = 8.0;
    float tau = 6.283185;
    a = mod(a, tau / sides) - tau / (sides * 2.0);
    a = abs(a);
    
    vec2 kuv = vec2(cos(a), sin(a)) * r;
    
    vec3 color = vec3(0.0);
    for (float i = 0.0; i < 4.0; i++) {
        float fi = i;
        kuv = abs(kuv) - 0.5 * (1.0 + 0.2 * sin(t * 0.5 + fi));
        
        // Rotation matrix
        float c = cos(t * 0.1 + fi);
        float s = sin(t * 0.1 + fi);
        kuv = vec2(kuv.x * c - kuv.y * s, kuv.x * s + kuv.y * c);
        
        float d = length(kuv);
        vec3 c = hsv2rgb(vec3(fract(d + t * 0.1 + fi * 0.2), 0.7, 1.0));
        color += c * (0.01 / (abs(d - 0.2) + 0.02));
    }
    
    // Vignette
    color *= smoothstep(1.0, 0.8, r);
    
    color *= intensity;
    return vec4(color, alpha);
}