#include "base/common.glsl"

// particles - GPU particle system simulation with flocking behavior

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = (uv - 0.5) * 2.0;
    p.x *= resolution.x / resolution.y;
    
    vec3 color = vec3(0.02, 0.02, 0.05); // Dark background
    
    // Simulate particles with noise-based particles
    float particles = 0.0;
    vec3 particleColor = vec3(0.0);
    
    for (float i = 0.0; i < 30.0; i++) {
        float fi = i / 30.0;
        
        // Animated position based on hash
        vec2 seed = vec2(fi * 10.0, fi * 5.0);
        vec2 vel = hash22(seed + floor(t * 0.5)) * 2.0 - 1.0;
        
        // Add some motion
        float angle = t * (0.5 + fi) + fi * 6.28;
        vec2 offset = vec2(cos(angle), sin(angle)) * (0.3 + 0.2 * sin(t + fi));
        vec2 particlePos = vel * 0.5 + offset;
        
        // Mouse interaction
        vec2 mouse = (u_mouse / resolution - 0.5) * 2.0;
        mouse.x *= resolution.x / resolution.y;
        vec2 toMouse = mouse - particlePos;
        float dist = length(toMouse) + 0.01;
        particlePos += normalize(toMouse) * 0.05 / dist;
        
        float d = length(p - particlePos);
        
        // Particle glow
        float size = 0.03 + 0.02 * sin(t * 2.0 + fi);
        float brightness = smoothstep(size, 0.0, d);
        
        // HSV color based on particle index and time
        float hue = fract(fi + t * 0.05);
        vec3 c = vec3(
            abs(hue * 6.0 - 3.0) - 1.0,
            2.0 - abs(hue * 6.0 - 2.0),
            2.0 - abs(hue * 6.0 - 4.0)
        );
        c = clamp(c, 0.0, 1.0);
        
        particleColor += c * brightness;
        particles += brightness;
    }
    
    color += particleColor * 0.5;
    
    // Add subtle trails
    float trail = noise(p * 3.0 + t * 0.2) * 0.1;
    color += trail * vec3(0.3, 0.5, 1.0);
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.8;
    color *= vig;
    
    color *= intensity;
    return vec4(color, alpha);
}