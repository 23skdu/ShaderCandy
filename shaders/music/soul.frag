#include "base/common.glsl"

// soul - Smooth, warm, emotional aesthetic

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
    
    // Warm, smooth background
    vec3 color = vec3(0.1, 0.05, 0.15);
    
    // Smooth flowing waves
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float waveY = sin(p.x * (1.5 + fi * 0.3) + t * (0.4 + fi * 0.1)) * (0.25 - fi * 0.03);
        waveY += sin(p.x * (1.0 + fi * 0.2) - t * (0.3 + fi * 0.08)) * 0.1;
        
        float wave = smoothstep(0.04, 0.0, abs(p.y - waveY));
        
        // Warm sunset colors
        vec3 waveColor = hsv2rgb(vec3(0.05 + fi * 0.03, 0.6 + fi * 0.05, 0.9));
        color += waveColor * wave * (0.7 - fi * 0.08);
    }
    
    // Soft glow in center
    float centerGlow = 1.0 - length(p) * 0.5;
    centerGlow = max(0.0, centerGlow);
    color += vec3(0.4, 0.2, 0.3) * centerGlow * 0.3;
    
    // Gentle shimmer
    float shimmer = noise(p * 8.0 + t * 0.2);
    color += vec3(0.3, 0.15, 0.25) * shimmer * 0.15;
    
    // Soft particles (like floating dust/light)
    for (float i = 0.0; i < 8.0; i++) {
        float fi = i;
        vec2 particlePos = vec2(
            sin(fi * 3.14 + t * 0.2) * 0.6,
            cos(fi * 2.71 + t * 0.15) * 0.4
        );
        float particle = smoothstep(0.03, 0.0, length(p - particlePos));
        color += vec3(1.0, 0.9, 0.8) * particle * 0.3;
    }
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}