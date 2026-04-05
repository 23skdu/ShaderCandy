#include "base/common.glsl"

// prism_core - Exploding geometric prism with volumetric light core

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
    
    // Rotate the coordinate system
    float c1 = cos(t * 0.2);
    float s1 = sin(t * 0.2);
    float c2 = cos(t * 0.3);
    float s2 = sin(t * 0.3);
    vec2 rotated = vec2(p.x * c1 - p.y * s1, p.x * s1 + p.y * c1);
    rotated = vec2(rotated.x * c2 - rotated.y * s2, rotated.x * s2 + rotated.y * c2);
    
    vec3 color = vec3(0.0);
    float glow = 0.0;
    
    // Simulate prism shape with rotating geometric patterns
    for (float i = 0.0; i < 6.0; i++) {
        float angle = i * 3.14159 / 3.0 + t * 0.5;
        vec2 dir = vec2(cos(angle), sin(angle));
        
        // Rotating lines forming prism
        float d = abs(dot(rotated, dir));
        float line = smoothstep(0.05, 0.0, d);
        
        // Cutting spheres create gaps
        vec2 spherePos = vec2(
            sin(t + i) * 1.2,
            cos(t * 1.5 + i) * 1.2
        );
        float sphere = length(rotated - spherePos) - 0.5;
        line *= smoothstep(-0.5, 0.0, sphere);
        
        // Color based on angle
        vec3 c = hsv2rgb(vec3(fract(t * 0.1 + i / 6.0), 0.7, 1.0));
        color += c * line * 0.5;
        
        // Glow around prism
        glow += 0.02 / (1.0 + d * 10.0);
    }
    
    // Center glow
    float centerDist = length(rotated);
    color += hsv2rgb(vec3(fract(t * 0.2), 0.8, 1.0)) * (0.1 / (centerDist + 0.1));
    color += glow * hsv2rgb(vec3(fract(t * 0.2), 0.8, 1.0));
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.3;
    
    color *= intensity;
    return vec4(color, alpha);
}