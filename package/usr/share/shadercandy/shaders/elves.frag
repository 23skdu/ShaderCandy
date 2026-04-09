#include "base/common.glsl"

// elves - Mystical forest with elves and magic wisps

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Deep enchanted forest background
    vec3 color = vec3(0.005, 0.02, 0.01);
    color += vec3(0.02, 0.08, 0.05) * (1.0 - length(p) * 0.3);
    
    // Trees (simple silhouettes)
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float treeX = sin(fi * 1.3) * 1.8;
        float treeH = 0.6 + fract(sin(fi * 127.1) * 43758.5453) * 0.4;
        
        vec2 treeP = p - vec2(treeX, treeH * 0.3 - 0.3);
        float trunk = max(abs(treeP.x) - 0.05, abs(treeP.y + treeH * 0.3) - treeH * 0.5);
        float canopy = length(treeP - vec2(0.0, treeH * 0.5)) - (0.3 + treeH * 0.15);
        
        float tree = min(smoothstep(0.02, 0.0, -trunk), smoothstep(0.02, 0.0, -canopy));
        
        vec3 treeColor = mix(vec3(0.08, 0.15, 0.06), vec3(0.1, 0.25, 0.1), canopy * 2.0);
        color = mix(color, treeColor, tree * 0.8);
    }
    
    // Ground
    if (p.y < -0.5) {
        color = vec3(0.1, 0.2, 0.08);
        // Mushrooms
        for (float i = 0.0; i < 3.0; i++) {
            float fi = i;
            vec2 mushP = p - vec2(-0.5 + fi * 0.5, -0.7);
            float mush = length(mushP) - 0.05;
            mush = smoothstep(0.02, 0.0, -mush);
            color = mix(color, vec3(0.9, 0.8, 0.7), mush);
        }
    }
    
    // Elves
    for (float i = 0.0; i < 4.0; i++) {
        float fi = i;
        float elfX = sin(fi * 2.0 + t * 0.2) * 1.0;
        float elfY = -0.5 + fi * 0.3;
        
        vec2 elfP = p - vec2(elfX, elfY);
        
        // Body
        float body = length(elfP * vec2(0.8, 1.0)) - 0.12;
        body = smoothstep(0.02, 0.0, -body);
        
        // Head
        vec2 headP = elfP - vec2(0.0, 0.25);
        float head = length(headP) - 0.08;
        head = smoothstep(0.02, 0.0, -head);
        
        // Pointed ears
        vec2 earLP = elfP - vec2(-0.1, 0.28);
        vec2 earRP = elfP - vec2(0.1, 0.28);
        float earL = max(abs(earLP.x) - 0.02, abs(earLP.y - 0.02) - 0.06);
        float earR = max(abs(earRP.x) - 0.02, abs(earRP.y - 0.02) - 0.06);
        float ears = max(smoothstep(0.01, 0.0, -earL), smoothstep(0.01, 0.0, -earR));
        
        // Hair
        vec2 hairP = elfP - vec2(0.0, 0.32);
        float hair = length(hairP) - 0.1;
        hair = smoothstep(0.02, 0.0, -hair);
        
        // Bow
        vec2 bowP = elfP - vec2(0.12, 0.1);
        float bow = length(bowP * vec2(1.5, 1.0)) - 0.15;
        bow = smoothstep(0.02, 0.0, -bow);
        
        float elf = max(body, head);
        elf = max(elf, ears);
        elf = max(elf, hair);
        elf = max(elf, bow);
        
        // Colors
        vec3 elfColor = vec3(0.2, 0.5, 0.3); // Green tunic
        elfColor = mix(elfColor, vec3(0.85, 0.75, 0.65), head); // Skin
        elfColor = mix(elfColor, vec3(0.9, 0.8, 0.4), hair); // Hair
        elfColor = mix(elfColor, vec3(0.4, 0.25, 0.15), bow); // Bow
        
        color = mix(color, elfColor, elf);
    }
    
    // Magic wisps
    for (float i = 0.0; i < 6.0; i++) {
        float fi = i;
        vec2 wispPos = vec2(
            sin(t * 0.5 + fi * 1.5) * 1.5,
            0.3 + cos(t * 0.3 + fi * 2.0) * 0.6
        );
        
        float wisp = length(p - wispPos) - (0.04 + 0.02 * sin(t * 3.0 + fi));
        wisp = smoothstep(0.02, 0.0, -wisp);
        
        vec3 wispColor = vec3(0.4, 0.9, 0.6);
        color = mix(color, wispColor * 2.0, wisp);
    }
    
    // Fireflies
    for (float i = 0.0; i < 15.0; i++) {
        float fi = i;
        vec2 fireflyPos = p + vec2(
            sin(t * 0.8 + fi * 3.0) * 0.5,
            cos(t * 0.6 + fi * 2.5) * 0.4
        );
        float firefly = smoothstep(0.015, 0.0, length(fireflyPos));
        firefly *= 0.5 + 0.5 * sin(t * 4.0 + fi * 2.0);
        color += vec3(0.5, 1.0, 0.3) * firefly * 0.5;
    }
    
    // Atmospheric glow
    vec3 glowColor = vec3(0.05, 0.15, 0.1);
    float glow = 0.15 * (1.0 - length(p) * 0.4);
    color += glowColor * glow;
    
    color *= intensity;
    return vec4(color, alpha);
}