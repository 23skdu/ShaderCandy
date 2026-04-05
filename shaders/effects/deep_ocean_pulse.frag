#include "base/common.glsl"

// deep_ocean_pulse - Bioluminescent organic blobs in an infinite abyss

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
    
    // Abyss background
    vec3 color = vec3(0.01, 0.02, 0.05);
    
    float glow = 0.0;
    vec3 blobColor = vec3(0.0);
    
    // Simulate 5 glowing blobs
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        
        vec2 blobPos = vec2(
            sin(t * 0.5 + fi) * 0.8,
            cos(t * 0.7 + fi * 1.5) * 0.6
        );
        
        float size = 0.15 + 0.1 * sin(t + fi);
        float dist = length(p - blobPos);
        
        // Soft blob glow
        float blob = smoothstep(size, size * 0.3, dist);
        
        // Fresnel-like effect
        float fre = pow(1.0 - dist * 0.5, 3.0);
        
        // Color based on position and time
        vec3 bColor = mix(vec3(0.0, 0.2, 0.4), hsv2rgb(vec3(0.5 + 0.2 * sin(t + fi), 0.8, 1.0)), fre);
        
        blobColor += bColor * blob;
        
        // Accumulate glow
        glow += 0.02 / (1.0 + dist * dist * 10.0);
    }
    
    color += blobColor * 0.8;
    color += glow * hsv2rgb(vec3(0.5 + 0.3 * cos(t * 0.2), 0.7, 1.0));
    
    // Add some particle-like sparkles
    float sparkle = pow(noise(p * 30.0 + t * 0.5), 12.0);
    color += sparkle * vec3(0.3, 0.5, 0.8);
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.6;
    color *= vig;
    
    color *= intensity;
    return vec4(color, alpha);
}