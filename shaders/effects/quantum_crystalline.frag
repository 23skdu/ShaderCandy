#include "base/common.glsl"

// quantum_crystalline - Infinite crystalline fractal geometry with rainbow refraction

// hsv2rgb provided by common.glsl

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = centered;
    
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
        
        // Composed rotation: (0.2*t + fi*0.3) + (0.3*t + fi*0.2) = 0.5 * (t + fi)
        float ang = 0.5 * (t + fi);
        float c = cos(ang);
        float s = sin(ang);
        q = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
    }
    
    dist = (length(q) - 0.5) / scale;
    
    // Glow based on distance to fractal
    float glow = 0.01 / (abs(dist) + 0.02);
    color += glow * hsv2rgb(vec3(fract(dist * 0.5 + t * 0.1), 0.7, 1.0));
    
    // Crystal surface
    if (dist < 0.1) {
        float pLen = length(p);
        float freBase = 1.0 - pLen * 0.3;
        float fre = freBase * freBase * freBase;
        color += fre * hsv2rgb(vec3(fract(dist * 2.0 + t * 0.2), 0.8, 1.0)) * 0.5;
    }
    
    // Add sparkle (pow 10)
    float n = noise(p * 20.0 + t);
    float n2 = n * n;
    float n4 = n2 * n2;
    float sparkle = n4 * n4 * n2;
    color += sparkle * vec3(1.0);
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.5;
    color *= vig;
    
    color *= intensity;
    return vec4(color, alpha);
}