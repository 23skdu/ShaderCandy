#include "base/common.glsl"

// hearts - Floating hearts with glowing effect

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.02, 0.0, 0.05);
    
    // Multiple floating hearts
    for (float i = 0.0; i < 8.0; i++) {
        float fi = i / 8.0;
        
        // Heart position - floating upward
        vec2 heartPos = vec2(
            sin(fi * 6.28 + t * 0.3) * 0.6,
            mod(fi * 0.8 + t * 0.1, 1.0) * 1.6 - 0.8
        );
        
        // Heart shape
        vec2 heartP = p - heartPos;
        float scale = 0.08 + 0.03 * sin(t * 2.0 + fi * 3.14);
        
        // Heart math: (x^2 + y^2 - 1)^3 - x^2 * y^3 < 0
        float x = heartP.x / scale;
        float y = heartP.y / scale;
        float heart = pow(x * x + y * y - 1.0, 3.0) - x * x * y * y * y;
        
        if (heart < 0.0) {
            // Pink/red gradient
            vec3 heartColor = mix(
                vec3(0.8, 0.1, 0.3),
                vec3(1.0, 0.4, 0.6),
                sin(t + fi) * 0.5 + 0.5
            );
            
            // Glow
            float glow = smoothstep(0.0, -0.1, heart) * 0.5;
            color += heartColor + glow * vec3(1.0, 0.5, 0.7);
        }
    }
    
    // Add sparkle
    float sparkle = pow(noise(p * 20.0 + t), 8.0);
    color += sparkle * vec3(1.0, 0.8, 0.9);
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}