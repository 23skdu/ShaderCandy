#include "base/common.glsl"

// vortex_dream - Infinite spiraling vortex of glowing particles and light

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
    
    float r = length(p);
    float a = atan(p.y, p.x);
    
    vec3 color = vec3(0.0);
    
    // Spiral layers
    for (float i = 0.0; i < 5.0; i++) {
        float spiral = a + log(r + 0.001) * 2.0 + t * (1.0 + i * 0.2);
        float line = fract(spiral * 1.5 + i * 0.5);
        
        float intensity = smoothstep(0.4, 0.5, line) * smoothstep(0.6, 0.5, line);
        vec3 c = hsv2rgb(vec3(fract(t * 0.05 + i * 0.2 + r * 0.5), 0.8, 1.0));
        
        color += c * intensity * (0.5 / (r + 0.1)) * exp(-r * 0.5);
    }
    
    // Core glow
    color += hsv2rgb(vec3(fract(t * 0.2), 0.6, 1.0)) * (0.05 / (r + 0.001));
    
    color *= intensity;
    return vec4(color, alpha);
}