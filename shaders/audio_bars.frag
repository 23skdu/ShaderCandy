#version 450 core

#include "base/common.glsl"

// Audio Bars - Audio frequency spectrum bars

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = centered;
    float t = time * speed;
    
    // Audio simulation (since we don't have real audio data)
    float bass = 0.5 + 0.5 * sin(t * 3.0);
    float mid = 0.5 + 0.5 * sin(t * 5.0 + 1.0);
    float treble = 0.5 + 0.5 * sin(t * 7.0 + 2.0);
    float beat = smoothstep(0.7, 1.0, bass);
    
    // Dark background
    vec3 color = vec3(0.02, 0.02, 0.04);
    
    // Bar parameters
    int numBars = 32;
    float barWidth = 1.8 / float(numBars);
    float startX = -0.9;
    float baseY = -0.5;
    float maxHeight = 1.2;
    
    // Draw bars
    for (int i = 0; i < 32; i++) {
        float fi = float(i);
        float x = startX + fi * barWidth;
        
        // Calculate bar height based on position (bass on left, treble on right)
        float position = fi / float(numBars);
        
        // Different frequency emphasis for each bar position
        float freqMix = position;
        float barHeight = mix(bass, treble, position) * maxHeight;
        
        // Add some variation
        barHeight *= 0.5 + 0.5 * sin(fi * 1.5 + t * 3.0);
        
        // Beat impact
        barHeight *= 1.0 + beat * 0.5;
        
        // Draw bar
        if (p.x > x && p.x < x + barWidth * 0.9 && p.y > baseY && p.y < baseY + barHeight) {
            // Gradient color based on height
            float heightRatio = (p.y - baseY) / barHeight;
            vec3 barColor = hsv2rgb(vec3(
                0.6 - heightRatio * 0.4 + t * 0.1,
                0.9,
                0.7 + heightRatio * 0.3
            ));
            color = barColor;
            
            // Add shine on top
            if (heightRatio > 0.9) {
                color += vec3(0.3);
            }
        }
        
        // Reflection below bars
        if (p.x > x && p.x < x + barWidth * 0.9 && p.y < baseY && p.y > baseY - barHeight * 0.3) {
            float reflectY = (baseY - p.y) / (barHeight * 0.3);
            float reflectHeight = barHeight * 0.3 * reflectY;
            
            if (reflectHeight < barHeight) {
                color = mix(color, vec3(0.1, 0.15, 0.2), reflectY * 0.5);
            }
        }
    }
    
    // Beat flash
    color += vec3(0.2, 0.1, 0.3) * beat * 0.3;
    
    // Grid lines
    vec2 grid = abs(fract(p * 5.0) - 0.5);
    float gridLine = smoothstep(0.48, 0.5, max(grid.x, grid.y));
    color += vec3(0.1) * gridLine * 0.2;
    
    color *= intensity;
    return vec4(color, alpha);
}
