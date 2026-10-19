#include "base/common.glsl"

// biolume_forest - Organic glowing mushrooms and trees in dark void

// hsv2rgb provided by common.glsl

// Precomputed colors
const vec3 cTreeGlows[3] = vec3[3](
    vec3(0.24, 0.6, 0.12),
    vec3(0.12, 0.6, 0.36),
    vec3(0.12, 0.54, 0.6)
);

const vec3 cMushColors[5] = vec3[5](
    vec3(0.1, 0.775, 1.0),
    vec3(0.1, 0.325, 1.0),
    vec3(0.425, 0.1, 1.0),
    vec3(0.875, 0.1, 1.0),
    vec3(1.0, 0.1, 0.675)
);

vec2 g_sporePos[15];

void setupSpores(float t) {
    for (int i = 0; i < 15; i++) {
        float fi = float(i);
        float sporeX = fract(sin(fi * 127.1) * 43758.5453) * 2.0 - 1.0;
        float sporeY = fract(sin(fi * 311.7) * 43758.5453) * 1.4 - 0.7;
        sporeY = mod(sporeY + t * 0.1 * (0.5 + fi * 0.1), 1.4) - 0.7;
        g_sporePos[i] = vec2(sporeX, sporeY);
    }
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    setupSpores(t);
    
    vec2 p = centered;
    
    // Dark void background
    vec3 color = vec3(0.01, 0.02, 0.03);
    
    // Ground plane
    float ground = smoothstep(-0.7, -0.65, p.y);
    color = mix(color, vec3(0.02, 0.04, 0.02), ground);
    
    // Glowing trees (simplified 2D)
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float treeX = -0.6 + fi * 0.6;
        float treeH = 0.4 + fi * 0.1;
        
        // Trunk
        float trunkDist = abs(p.x - treeX) - 0.03;
        
        if (trunkDist < 0.0 && p.y > -0.7 && p.y < treeH) {
            color = vec3(0.1, 0.08, 0.05);
        }
        
        // Tree crown / canopy glow
        vec2 crownPos = vec2(treeX, treeH * 0.7);
        float crownDist = length((p - crownPos) * vec2(1.0, 0.7));
        float crown = smoothstep(0.25, 0.0, crownDist);
        color += cTreeGlows[i] * crown * 0.4;
    }
    
    // Glowing mushrooms
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float mushX = -0.8 + fi * 0.4 + sin(t * 0.5 + fi) * 0.05;
        if (abs(p.x - mushX) > 0.2) continue;
        float mushY = -0.65;
        
        // Stem
        float stemDist = abs(p.x - mushX) - 0.015;
        if (stemDist < 0.0 && p.y > mushY && p.y < mushY + 0.08) {
            color = vec3(0.9, 0.85, 0.7);
        }
        
        // Cap (glowing)
        vec2 capPos = vec2(mushX, mushY + 0.1);
        float capDist = length((p - capPos) * vec2(1.5, 1.0));
        float cap = smoothstep(0.08, 0.0, capDist);
        
        float pulse = 0.7 + 0.3 * sin(t * 2.0 + fi);
        color += cMushColors[i] * cap * pulse;
    }
    
    // Floating spores / particles
    for (int i = 0; i < 15; i++) {
        vec2 diff = p - g_sporePos[i];
        if (abs(diff.x) > 0.03) continue;
        
        float dist = length(diff);
        float spore = smoothstep(0.015, 0.0, dist);
        
        float fi = float(i);
        vec3 sporeColor = hsv2rgb(vec3(0.6 + fi * 0.03, 0.7, 0.9));
        color += sporeColor * spore * 0.5;
    }
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.6;
    
    color *= intensity;
    return vec4(color, alpha);
}