#version 450 core

#include "base/common.glsl"

// Byzantine - Byzantine mosaic patterns

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Byzantine tile pattern
float byzantineTile(vec2 p, float t) {
    float pattern = 0.0;
    
    // Grid of tiles
    vec2 tile = fract(p * 4.0);
    vec2 tileId = floor(p * 4.0);
    
    // Rotation based on tile position
    float rotation = mod(tileId.x + tileId.y, 4.0) * PI * 0.5;
    tile -= 0.5;
    tile *= rot(rotation + t * 0.1);
    tile += 0.5;
    
    // Central cross
    float cross = smoothstep(0.15, 0.12, abs(tile.x - 0.5)) + 
                  smoothstep(0.15, 0.12, abs(tile.y - 0.5));
    cross = min(cross, 1.0);
    
    // Corner decorations
    vec2 corner = abs(tile - 0.5);
    float cornerDeco = smoothstep(0.35, 0.25, length(corner));
    
    // Border
    float border = max(
        smoothstep(0.02, 0.0, tile.x) + smoothstep(0.98, 1.0, tile.x),
        smoothstep(0.02, 0.0, tile.y) + smoothstep(0.98, 1.0, tile.y)
    );
    border = min(border, 1.0);
    
    return cross + cornerDeco * 0.5 + border * 0.3;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    vec2 p = centered;
    
    // Background - deep blue
    vec3 col = vec3(0.05, 0.05, 0.2);
    
    // Byzantine colors
    vec3 gold = vec3(0.9, 0.75, 0.2);
    vec3 red = vec3(0.7, 0.1, 0.1);
    vec3 blue = vec3(0.1, 0.2, 0.6);
    vec3 green = vec3(0.1, 0.5, 0.2);
    
    // Pattern
    float pattern = byzantineTile(p, t);
    
    // Color based on pattern parts
    vec2 tile = fract(p * 4.0) - 0.5;
    vec2 tileId = floor(p * 4.0);
    float colorVar = hash(tileId.x + tileId.y * 57.0 + t * 0.1);
    
    vec3 patternCol;
    if(colorVar < 0.33) {
        patternCol = mix(gold, red, pattern);
    } else if(colorVar < 0.66) {
        patternCol = mix(blue, gold, pattern);
    } else {
        patternCol = mix(green, blue, pattern);
    }
    
    col = mix(col, patternCol, smoothstep(0.0, 1.0, pattern));
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
