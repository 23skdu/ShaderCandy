#version 450 core

#include "base/common.glsl"

// System Debug Overlay - Debug visualization shader

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = centered;
    
    // Dark background
    vec3 col = vec3(0.05, 0.05, 0.05);
    
    // Grid
    vec2 grid = abs(fract(p * 10.0) - 0.5);
    float gridLine = smoothstep(0.48, 0.5, max(grid.x, grid.y));
    col += vec3(0.1) * gridLine;
    
    // Axes
    float axes = smoothstep(0.01, 0.0, min(abs(p.x), abs(p.y)));
    col += vec3(0.3, 0.3, 0.4) * axes;
    
    // Resolution indicator
    vec2 resIndicator = step(0.9, abs(p));
    col += vec3(0.5, 0.0, 0.0) * max(resIndicator.x, resIndicator.y) * 0.5;
    
    // Center crosshair
    float crosshair = smoothstep(0.02, 0.0, abs(p.x)) + smoothstep(0.02, 0.0, abs(p.y));
    col += vec3(0.0, 1.0, 0.0) * crosshair;
    
    // Time visualization (rotating bar)
    float angle = time * speed;
    vec2 rotP = vec2(
        p.x * cos(angle) - p.y * sin(angle),
        p.x * sin(angle) + p.y * cos(angle)
    );
    float timeBar = smoothstep(0.05, 0.0, abs(rotP.y)) * step(0.0, rotP.x) * step(rotP.x, 0.8);
    col += vec3(1.0, 1.0, 0.0) * timeBar;
    
    // Frame indicator (border)
    float border = max(abs(p.x), abs(p.y));
    col = mix(col, vec3(0.0, 0.5, 1.0), smoothstep(0.98, 1.0, border));
    
    col *= intensity;
    return vec4(col, alpha);
}
