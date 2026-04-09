#version 450 core

#include "base/common.glsl"

// Audio Circular - Circular audio visualization

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = centered;
    float t = time * speed;
    
    // Audio simulation
    float bass = 0.5 + 0.5 * sin(t * 3.0);
    float mid = 0.5 + 0.5 * sin(t * 5.0 + 1.0);
    float treble = 0.5 + 0.5 * sin(t * 7.0 + 2.0);
    float beat = smoothstep(0.7, 1.0, bass);
    
    // Dark background
    vec3 color = vec3(0.01, 0.01, 0.02);
    
    float radius = length(p);
    float angle = atan(p.y, p.x);
    
    // Circular bars
    int numSegments = 64;
    float segmentAngle = TWO_PI / float(numSegments);
    int segment = int((angle + PI) / segmentAngle);
    float fi = float(segment);
    
    // Calculate bar height based on segment position
    float position = fi / float(numSegments);
    float barValue = mix(bass, treble, position);
    barValue *= 0.5 + 0.5 * sin(fi * 0.5 + t * 3.0);
    barValue *= 1.0 + beat * 0.3;
    
    float innerRadius = 0.2;
    float outerRadius = innerRadius + barValue * 0.6;
    
    // Draw circular bar
    if (radius > innerRadius && radius < outerRadius) {
        // Gradient color
        vec3 barColor = hsv2rgb(vec3(
            position + t * 0.1,
            0.9,
            0.7 + barValue * 0.3
        ));
        color = barColor;
    }
    
    // Center circle
    if (radius < innerRadius) {
        // Pulsing center
        float pulse = 0.5 + 0.5 * sin(t * 10.0);
        color = vec3(0.3, 0.5, 1.0) * (0.5 + beat * 0.5);
        color += vec3(0.2, 0.3, 0.5) * pulse;
    }
    
    // Outer glow ring
    float glowRing = smoothstep(outerRadius + 0.1, outerRadius, radius);
    color += vec3(0.3, 0.2, 0.5) * glowRing * barValue * 0.5;
    
    // Beat flash background
    color += vec3(0.05, 0.02, 0.1) * beat * 0.5;
    
    // Vignette
    color *= 1.0 - radius * 0.3;
    
    color *= intensity;
    return vec4(color, alpha);
}
