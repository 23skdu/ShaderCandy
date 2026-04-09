#include "base/common.glsl"

// retro_robot - 1950s "Raygun Gothic" style robot face

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
    
    vec3 color = vec3(0.1, 0.1, 0.12);
    
    // Robot head shape (rounded rectangle)
    vec2 headSize = vec2(0.4, 0.35);
    vec2 headPos = p - vec2(0.0, 0.1);
    vec2 d = abs(headPos) - headSize;
    float headDist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - 0.08;
    
    if (headDist < 0.0) {
        color = vec3(0.5, 0.5, 0.55); // Metal body
        
        // Add scratches
        color *= 0.8 + 0.2 * noise(p * 10.0);
    }
    
    // Eyes (glowing)
    vec2 eyeL = p - vec2(-0.15, 0.15);
    vec2 eyeR = p - vec2(0.15, 0.15);
    float eyeDistL = length(eyeL) - 0.08;
    float eyeDistR = length(eyeR) - 0.08;
    
    if (eyeDistL < 0.0) {
        float pulse = 0.8 + 0.2 * sin(t * 10.0);
        color = vec3(1.0, 0.3, 0.1) * pulse * 2.0;
    }
    if (eyeDistR < 0.0) {
        float pulse = 0.8 + 0.2 * sin(t * 10.0);
        color = vec3(1.0, 0.3, 0.1) * pulse * 2.0;
    }
    
    // Antenna
    vec2 antP = p - vec2(0.0, 0.5);
    float antDist = length(antP) - 0.02;
    if (antP.y > 0.0 && antP.y < 0.15 && abs(antP.x) < 0.015) {
        color = vec3(0.4, 0.4, 0.45);
    }
    // Antenna bulb
    float bulbDist = length(p - vec2(0.0, 0.65)) - 0.04;
    if (bulbDist < 0.0) {
        float pulse = 0.7 + 0.3 * sin(t * 5.0);
        color = vec3(1.0, 0.2, 0.1) * pulse * 1.5;
    }
    
    // Mouth area
    vec2 mouthP = p - vec2(0.0, -0.05);
    if (abs(mouthP.x) < 0.2 && abs(mouthP.y) < 0.08) {
        color = vec3(0.15, 0.15, 0.18);
        // Grill lines
        for (float i = 0.0; i < 5.0; i++) {
            float x = -0.15 + i * 0.075;
            if (abs(mouthP.x - x) < 0.01) {
                color = vec3(0.0);
            }
        }
    }
    
    // Ears/antenna on sides
    if ((p.x > 0.5 && p.x < 0.6 && p.y > 0.0 && p.y < 0.3) ||
        (p.x < -0.5 && p.x > -0.6 && p.y > 0.0 && p.y < 0.3)) {
        color = vec3(0.4, 0.4, 0.45);
    }
    
    // Retro film grain and flicker
    float grain = noise(p * 100.0 + t);
    color += grain * 0.05;
    color *= 0.9 + 0.1 * sin(t * 50.0);
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}