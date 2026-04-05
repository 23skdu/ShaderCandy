#include "base/common.glsl"

// heavymetal - Aggressive dark red/black with lightning and chaos

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
    
    // Dark red/black background
    vec3 color = vec3(0.05, 0.0, 0.02);
    
    // Aggressive noise pattern
    float n = noise(p * 3.0 + t * 0.5);
    n += noise(p * 6.0 - t * 0.3) * 0.5;
    n += noise(p * 12.0 + t * 0.7) * 0.25;
    
    // Dark red/orange flames
    vec3 flameColor = mix(vec3(0.2, 0.0, 0.0), vec3(0.8, 0.2, 0.0), n);
    color = mix(color, flameColor, n * 0.6);
    
    // Lightning flashes
    float lightning = pow(noise(p * 10.0 + t * 5.0), 8.0);
    lightning += pow(noise(p * 15.0 - t * 3.0), 10.0);
    color += vec3(1.0, 0.9, 0.8) * lightning * 0.8;
    
    // Chaos lines
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float lineY = sin(p.x * 5.0 + t * 2.0 + fi) * 0.3;
        float line = smoothstep(0.02, 0.0, abs(p.y - lineY));
        
        float flash = step(0.8, fract(t * 0.3 + fi * 0.15));
        color += vec3(1.0, 0.3, 0.1) * line * flash * 0.5;
    }
    
    // Edge glow
    float edge = length(p) * 0.5;
    color += vec3(0.3, 0.0, 0.1) * edge * 0.3;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.6;
    
    color *= intensity;
    return vec4(color, alpha);
}