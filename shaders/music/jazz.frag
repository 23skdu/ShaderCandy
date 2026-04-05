#include "base/common.glsl"

// jazz - Smooth flowing curves with warm brass tones and blue-purple palette

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
    
    // Deep blue-purple background
    vec3 color = vec3(0.02, 0.01, 0.08);
    
    // Smooth flowing curves
    for (float i = 0.0; i < 6.0; i++) {
        float fi = i;
        float curveY = sin(p.x * (2.0 + fi * 0.5) + t * (0.3 + fi * 0.1) + fi) * (0.3 + fi * 0.05);
        curveY += sin(p.x * (1.5 + fi * 0.3) - t * (0.2 + fi * 0.05)) * 0.15;
        
        float line = smoothstep(0.03, 0.0, abs(p.y - curveY));
        
        // Warm brass/gold tones
        vec3 curveColor = hsv2rgb(vec3(0.1 + fi * 0.05, 0.7, 0.9));
        color += curveColor * line * (0.6 - fi * 0.05);
    }
    
    // Saxophone-like flow
    float saxFlow = sin(p.x * 3.0 + t * 0.8) * sin(p.y * 2.0 + t * 0.5);
    saxFlow = smoothstep(0.3, 0.8, saxFlow);
    color += vec3(0.6, 0.3, 0.5) * saxFlow * 0.2;
    
    // Smooth shimmer
    float shimmer = noise(p * 5.0 + t * 0.3);
    color += vec3(0.4, 0.3, 0.6) * shimmer * 0.1;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}