#include "base/common.glsl"

// vaporwave - Retro 80s/90s aesthetic with neon grids, sunsets, and floating retro tech

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Sunset background
    vec3 col = vec3(0.0);
    vec3 topColor = vec3(0.05, 0.02, 0.15);
    vec3 midColor = vec3(0.8, 0.3, 0.6);
    vec3 bottomColor = vec3(1.0, 0.7, 0.3);
    
    float gradT = uv.y;
    col = mix(bottomColor, midColor, smoothstep(0.0, 0.4, gradT));
    col = mix(col, topColor, smoothstep(0.4, 1.0, gradT));
    
    // Neon grid floor
    vec2 gridP = p;
    gridP.y += 0.5;
    vec2 grid = abs(fract(gridP * 4.0 - vec2(0.0, t * 0.5)) - 0.5) * 2.0;
    float g = min(grid.x, grid.y);
    g = smoothstep(0.1, 0.0, g);
    float gridFade = smoothstep(1.5, -0.5, p.y);
    col = mix(col, vec3(0.0, 0.8, 1.0), g * gridFade * 0.6);
    
    // Retro sun (large gradient circle)
    vec2 sunPos = vec2(0.0, 0.3);
    float sunDist = length(p - sunPos);
    float sun = smoothstep(0.6, 0.55, sunDist);
    vec3 sunColor = mix(vec3(1.0, 0.8, 0.3), vec3(1.0, 0.3, 0.5), uv.y);
    col = mix(col, sunColor, sun);
    
    // Sun stripes (classic vaporwave)
    for (float i = 0.0; i < 6.0; i++) {
        float stripeY = sunPos.y - 0.1 - i * 0.08;
        if (p.y < stripeY && p.y > stripeY - 0.03 && sunDist < 0.55) {
            col = mix(col, topColor, 0.8);
        }
    }
    
    // Floating geometry (simplified 2D shapes)
    // Pink marble column
    vec2 colPos = vec2(-0.5, -0.2);
    vec2 colP = p - colPos;
    float colDist = length(colP * vec2(1.0, 0.4));
    if (colDist < 0.15) {
        col = vec3(0.9, 0.4, 0.6);
    }
    
    // Greek bust silhouette (simplified)
    vec2 bustPos = vec2(0.5, -0.3);
    vec2 bustP = p - bustPos;
    float bustDist = length(bustP * vec2(1.0, 0.7));
    if (bustDist < 0.12 && p.y > -0.4) {
        col = vec3(0.95, 0.9, 0.85);
    }
    
    // Palm tree silhouette
    vec2 palmPos = vec2(-1.2, -0.7);
    vec2 trunkP = p - palmPos;
    if (abs(trunkP.x) < 0.03 && trunkP.y > -0.5 && trunkP.y < 0.3) {
        col = vec3(0.0);
    }
    // Palm leaves
    for (float i = 0.0; i < 5.0; i++) {
        float angle = i * 1.2 - 0.5;
        vec2 leafEnd = palmPos + vec2(cos(angle) * 0.4, 0.3 + sin(i) * 0.1);
        vec2 toLeaf = leafEnd - palmPos;
        float l = length(p - palmPos - toLeaf * clamp(dot(p - palmPos, toLeaf) / dot(toLeaf, toLeaf), 0.0, 1.0));
        if (l < 0.02 && p.y > palmPos.y) {
            col = vec3(0.0);
        }
    }
    
    // Scanlines
    float scanline = sin(uv.y * resolution.y * 0.5) * 0.03;
    col -= scanline;
    
    // Digital noise
    float noise = fract(sin(dot(uv + t, vec2(12.9898, 78.233))) * 43758.5453);
    col += noise * 0.02;
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.8;
    col *= vig;
    
    col *= intensity;
    return vec4(col, alpha);
}