#include "base/common.glsl"

// particles - GPU particle system simulation with flocking behavior

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec2 g_partPos[30];
vec3 g_partCol[30];
float g_partSize[30];

void setupParticles(float t, vec2 mPos) {
    for (int i = 0; i < 30; i++) {
        float fi = float(i) * 0.03333333;
        
        // Animated position based on hash
        vec2 seed = vec2(fi * 10.0, fi * 5.0);
        vec2 vel = hash22(seed + floor(t * 0.5)) * 2.0 - 1.0;
        
        // Add some motion
        float angle = t * (0.5 + fi) + fi * 6.28;
        vec2 offset = vec2(cos(angle), sin(angle)) * (0.3 + 0.2 * sin(t + fi));
        vec2 particlePos = vel * 0.5 + offset;
        
        // Mouse interaction
        vec2 toMouse = mPos - particlePos;
        float dist = length(toMouse) + 0.01;
        particlePos += normalize(toMouse) * (0.05 / dist);
        
        g_partPos[i] = particlePos;
        g_partSize[i] = 0.03 + 0.02 * sin(t * 2.0 + fi);
        
        // HSV color based on particle index and time
        float hue = fract(fi + t * 0.05);
        vec3 c = vec3(
            abs(hue * 6.0 - 3.0) - 1.0,
            2.0 - abs(hue * 6.0 - 2.0),
            2.0 - abs(hue * 6.0 - 4.0)
        );
        g_partCol[i] = clamp(c, 0.0, 1.0);
    }
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 mPos = (mouse - 0.5) * 2.0;
    mPos.x *= resolution.x / resolution.y;
    setupParticles(t, mPos);
    
    vec3 color = vec3(0.02, 0.02, 0.05); // Dark background
    
    // Simulate particles with noise-based particles
    float particles = 0.0;
    vec3 particleColor = vec3(0.0);
    
    for (int i = 0; i < 30; i++) {
        float d = length(centered - g_partPos[i]);
        float brightness = smoothstep(g_partSize[i], 0.0, d);
        particleColor += g_partCol[i] * brightness;
        particles += brightness;
    }
    
    color += particleColor * 0.5;
    
    // Add subtle trails
    float trail = noise(centered * 3.0 + t * 0.2) * 0.1;
    color += trail * vec3(0.3, 0.5, 1.0);
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.8;
    color *= vig;
    
    color *= intensity;
    return vec4(color, alpha);
}