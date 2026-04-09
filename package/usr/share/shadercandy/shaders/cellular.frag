#version 450 core

#include "base/common.glsl"

// Cellular - Cellular automata patterns

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Cellular pattern generator
float cellular(vec2 p, float t) {
    float pattern = 0.0;
    
    // Grid size
    vec2 grid = p * 8.0;
    vec2 cell = fract(grid);
    vec2 cellId = floor(grid);
    
    // Cellular movement
    vec2 cellCenter = vec2(
        hash(cellId.x + cellId.y * 57.0 + t * 0.1),
        hash(cellId.x * 23.0 + cellId.y * 31.0 + t * 0.1)
    );
    
    // Distance to cell center
    float dist = length(cell - cellCenter);
    
    // Cell borders
    vec2 border = abs(cell - 0.5);
    float borderDist = max(border.x, border.y);
    
    // Pattern based on cell state
    float cellState = hash(cellId.x * 17.0 + cellId.y * 43.0 + floor(t));
    
    // Create organic cell shapes
    float cellShape = smoothstep(0.5, 0.0, dist);
    
    // Voronoi-like edges
    float edge = smoothstep(0.55, 0.5, borderDist);
    
    return cellShape + edge * 0.3;
}

// Game of Life-like pattern
float gameOfLife(vec2 p, float t) {
    vec2 grid = p * 20.0;
    vec2 cell = fract(grid);
    vec2 cellId = floor(grid);
    
    // Simulate cell states
    float state = 0.0;
    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 neighbor = cellId + vec2(float(x), float(y));
            float neighborState = hash(neighbor.x * 17.0 + neighbor.y * 43.0 + floor(t));
            state += neighborState;
        }
    }
    
    state /= 9.0;
    
    // Cell alive if threshold met
    float alive = step(0.4, state) * (1.0 - step(0.6, state));
    
    return alive;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    vec2 p = centered;
    
    // Background - dark
    vec3 col = vec3(0.02, 0.02, 0.05);
    
    // Cellular pattern
    float cellPattern = cellular(p, t);
    
    // Living cell colors
    vec3 liveCell = vec3(0.2, 0.8, 0.3);
    vec3 deadCell = vec3(0.1, 0.1, 0.2);
    vec3 borderCol = vec3(0.5, 0.5, 0.7);
    
    // Apply pattern
    vec3 cellCol = mix(deadCell, liveCell, cellPattern);
    
    // Add borders
    vec2 grid = p * 8.0;
    vec2 border = abs(fract(grid) - 0.5);
    float borderLine = smoothstep(0.48, 0.5, max(border.x, border.y));
    cellCol += borderCol * borderLine * 0.2;
    
    // Mix with background
    col = mix(col, cellCol, 0.8);
    
    // Glow effect
    col += liveCell * cellPattern * 0.2;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
