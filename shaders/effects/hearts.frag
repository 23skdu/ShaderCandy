#include "base/common.glsl"

// hearts - Floating hearts with glowing effect

vec2 g_heartPos[8];
float g_heartInvScale[8];
vec3 g_heartColor[8];

void setupHearts(float t) {
    for (int i = 0; i < 8; i++) {
        float fi = float(i) * 0.125;
        g_heartPos[i] = vec2(
            sin(fi * 6.28 + t * 0.3) * 0.6,
            mod(fi * 0.8 + t * 0.1, 1.0) * 1.6 - 0.8
        );
        float scale = 0.08 + 0.03 * sin(t * 2.0 + fi * 3.14);
        g_heartInvScale[i] = 1.0 / scale;
        g_heartColor[i] = mix(
            vec3(0.8, 0.1, 0.3),
            vec3(1.0, 0.4, 0.6),
            sin(t + fi) * 0.5 + 0.5
        );
    }
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    setupHearts(t);
    
    vec2 p = centered;
    
    vec3 color = vec3(0.02, 0.0, 0.05);
    
    // Multiple floating hearts
    for (int i = 0; i < 8; i++) {
        // Heart shape
        vec2 heartP = p - g_heartPos[i];
        float invS = g_heartInvScale[i];
        
        // Heart math: (x^2 + y^2 - 1)^3 - x^2 * y^3 < 0
        float x = heartP.x * invS;
        float y = heartP.y * invS;
        float x2 = x * x;
        float y2 = y * y;
        float hTerm = x2 + y2 - 1.0;
        float heart = hTerm * hTerm * hTerm - x2 * y2 * y;
        
        if (heart < 0.0) {
            // Glow
            float glow = smoothstep(0.0, -0.1, heart) * 0.5;
            color += g_heartColor[i] + glow * vec3(1.0, 0.5, 0.7);
        }
    }
    
    // Add sparkle (pow 8)
    float n = noise(p * 20.0 + t);
    float n2 = n * n;
    float n4 = n2 * n2;
    float sparkle = n4 * n4;
    color += sparkle * vec3(1.0, 0.8, 0.9);
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}