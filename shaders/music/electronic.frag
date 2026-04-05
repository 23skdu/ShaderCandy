#include "base/common.glsl"

// electronic - Cyber motherboard with audio-reactive elements

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
    
    // Deep blue background
    vec3 color = vec3(0.01, 0.02, 0.05);
    
    // Simulate audio energy with time-based pulses
    float bassPulse = 0.5 + 0.5 * sin(t * 3.0);
    float midPulse = 0.5 + 0.5 * sin(t * 5.0 + 1.0);
    float treblePulse = 0.5 + 0.5 * sin(t * 7.0 + 2.0);
    
    // Grid of chips
    vec2 gridId = floor(p * 4.0);
    vec2 gridP = fract(p * 4.0) - 0.5;
    
    // Random chip height
    float chipH = fract(sin(dot(gridId, vec2(127.1, 311.7))) * 43758.5453);
    float h = 0.1 + 0.3 * chipH + 0.2 * bassPulse;
    
    // Chip rectangle
    float chipDist = max(abs(gridP.x) - 0.35, abs(gridP.y) - h * 0.3);
    float chip = smoothstep(0.02, 0.0, chipDist);
    
    // Chip color
    vec3 chipColor = hsv2rgb(vec3(0.6 + gridId.x * 0.1, 0.8, 0.8));
    color += chipColor * chip * 0.6;
    
    // CPU in center
    float cpuDist = max(abs(p.x) - 0.6, abs(p.y) - 0.3 - bassPulse * 0.15);
    float cpu = smoothstep(0.03, 0.0, cpuDist);
    vec3 cpuColor = vec3(0.0, 0.8, 1.0);
    color += cpuColor * cpu * 0.8;
    
    // CPU details (lines)
    for (float i = 0.0; i < 4.0; i++) {
        float lineY = -0.2 + i * 0.15;
        float line = smoothstep(0.01, 0.0, abs(p.y - lineY)) * smoothstep(0.5, 0.6, abs(p.x));
        color += vec3(0.2, 0.5, 1.0) * line * 0.3;
    }
    
    // Data buses (connecting lines)
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float busY = -0.8 + fi * 0.4;
        float bus = smoothstep(0.015, 0.0, abs(p.y - busY));
        
        // Pulsing based on time
        float busPulse = step(0.5, fract(t * 0.5 + fi * 0.2));
        vec3 busColor = hsv2rgb(vec3(0.5 + fi * 0.1, 0.9, 1.0));
        color += busColor * bus * busPulse * 0.4;
    }
    
    // Glowing traces
    float trace = sin(p.x * 30.0 + t * 2.0) * sin(p.y * 30.0 + t);
    trace = smoothstep(0.5, 0.8, trace);
    color += vec3(0.0, 0.4, 0.8) * trace * 0.1;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}