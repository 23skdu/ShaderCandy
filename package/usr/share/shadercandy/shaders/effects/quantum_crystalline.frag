#include "base/common.glsl"

// quantum_crystalline - Infinite crystalline fractal geometry with rainbow refraction

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
    
    vec3 color = vec3(0.0);
    
    // Simulate crystalline fractal pattern
    vec2 q = p;
    float scale = 1.0;
    float dist = 0.0;
    
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        q = abs(q) - 1.2;
        float r2 = dot(q, q);
        float k = 1.5 / (r2 + 0.001);
        q *= k;
        scale *= k;
        
        // Rotation
        float c1 = cos(0.2 * t + fi * 0.3);
        float s1 = sin(0.2 * t + fi * 0.3);
        float c2 = cos(0.3 * t + fi * 0.2);
        float s2 = sin(0.3 * t + fi * 0.2);
        q = vec2(q.x * c1 - q.y * s1, q.x * s1 + q.y * c1);
        q = vec2(q.x * c2 - q.y * s2, q.x * s2 + q.y * c2);
    }
    
    dist = (length(q) - 0.5) / scale;
    
    // Glow based on distance to fractal
    float glow = 0.01 / (abs(dist) + 0.02);
    color += glow * hsv2rgb(vec3(fract(dist * 0.5 + t * 0.1), 0.7, 1.0));
    
    // Crystal surface
    if (dist < 0.1) {
        float fre = pow(1.0 - length(p) * 0.3, 3.0);
        color += fre * hsv2rgb(vec3(fract(dist * 2.0 + t * 0.2), 0.8, 1.0)) * 0.5;
    }
    
    // Add sparkle
    float sparkle = pow(noise(p * 20.0 + t), 10.0);
    color += sparkle * vec3(1.0);
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.5;
    color *= vig;
    
    color *= intensity;
    return vec4(color, alpha);
}