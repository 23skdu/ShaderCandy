#include "base/common.glsl"

// biolume_forest - Organic glowing mushrooms and trees in dark void

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
    
    // Dark void background
    vec3 color = vec3(0.01, 0.02, 0.03);
    
    // Ground plane
    float ground = smoothstep(-0.7, -0.65, p.y);
    color = mix(color, vec3(0.02, 0.04, 0.02), ground);
    
    // Glowing trees (simplified 2D)
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        float treeX = -0.6 + fi * 0.6;
        float treeH = 0.4 + fi * 0.1;
        
        // Trunk
        float trunkDist = abs(p.x - treeX) - 0.03;
        float trunkH = smoothstep(treeH, 0.0, p.y) * smoothstep(-0.7, -0.65, p.y);
        
        if (trunkDist < 0.0 && p.y > -0.7 && p.y < treeH) {
            color = vec3(0.1, 0.08, 0.05);
        }
        
        // Tree crown / canopy glow
        vec2 crownPos = vec2(treeX, treeH * 0.7);
        float crownDist = length((p - crownPos) * vec2(1.0, 0.7));
        float crown = smoothstep(0.25, 0.0, crownDist);
        vec3 treeGlow = hsv2rgb(vec3(0.3 + fi * 0.1, 0.8, 0.6));
        color += treeGlow * crown * 0.4;
    }
    
    // Glowing mushrooms
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float mushX = -0.8 + fi * 0.4 + sin(t * 0.5 + fi) * 0.05;
        float mushY = -0.65;
        
        // Stem
        float stemDist = abs(p.x - mushX) - 0.015;
        float stemH = smoothstep(mushY + 0.08, mushY, p.y);
        if (stemDist < 0.0 && p.y > mushY && p.y < mushY + 0.08) {
            color = vec3(0.9, 0.85, 0.7);
        }
        
        // Cap (glowing)
        vec2 capPos = vec2(mushX, mushY + 0.1);
        float capDist = length((p - capPos) * vec2(1.5, 1.0));
        float cap = smoothstep(0.08, 0.0, capDist);
        
        // Color based on mushroom index
        vec3 mushColor = hsv2rgb(vec3(0.5 + fi * 0.1, 0.9, 1.0));
        float pulse = 0.7 + 0.3 * sin(t * 2.0 + fi);
        color += mushColor * cap * pulse;
    }
    
    // Floating spores / particles
    for (float i = 0.0; i < 15.0; i++) {
        float fi = i;
        float sporeX = fract(sin(fi * 127.1) * 43758.5453) * 2.0 - 1.0;
        float sporeY = fract(sin(fi * 311.7) * 43758.5453) * 1.4 - 0.7;
        sporeY = mod(sporeY + t * 0.1 * (0.5 + fi * 0.1), 1.4) - 0.7;
        
        float dist = length(p - vec2(sporeX, sporeY));
        float spore = smoothstep(0.015, 0.0, dist);
        
        vec3 sporeColor = hsv2rgb(vec3(0.6 + fi * 0.03, 0.7, 0.9));
        color += sporeColor * spore * 0.5;
    }
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.6;
    
    color *= intensity;
    return vec4(color, alpha);
}