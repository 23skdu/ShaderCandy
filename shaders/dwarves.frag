#include "base/common.glsl"

// dwarves - Underground forge with dwarves

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Dark cave background
    vec3 color = vec3(0.03, 0.02, 0.01);
    
    // Forge glow (flickering)
    float flicker = 0.8 + 0.2 * sin(t * 25.0) + 0.1 * sin(t * 50.0);
    vec2 forgePos = vec2(0.0, 0.5);
    float forgeDist = length(p - forgePos);
    vec3 forgeGlow = vec3(1.0, 0.3, 0.05) * 0.5 / (1.0 + forgeDist * 2.0);
    color += forgeGlow * flicker;
    
    // Forge/furnace
    vec2 furnaceP = p - vec2(0.0, 0.3);
    float furnace = max(abs(furnaceP.x) - 0.4, abs(furnaceP.y + 0.1) - 0.3);
    furnace = smoothstep(0.02, 0.0, -furnace);
    vec3 furnaceColor = vec3(0.15, 0.12, 0.1);
    color = mix(color, furnaceColor, furnace);
    
    // Fire opening
    vec2 fireP = p - vec2(0.0, 0.15);
    float fire = max(abs(fireP.x) - 0.25, abs(fireP.y + 0.1) - 0.15);
    fire = smoothstep(0.02, 0.0, -fire);
    vec3 fireColor = vec3(1.0, 0.2 + flicker * 0.1, 0.0);
    color = mix(color, fireColor, fire);
    
    // Anvil
    vec2 anvilP = p - vec2(-0.6, -0.3);
    float anvilBase = max(abs(anvilP.x) - 0.3, abs(anvilP.y + 0.15) - 0.08);
    float anvilTop = max(abs(anvilP.x) - 0.18, abs(anvilP.y) - 0.05);
    float anvil = max(smoothstep(0.02, 0.0, -anvilBase), smoothstep(0.02, 0.0, -anvilTop));
    color = mix(color, vec3(0.25, 0.22, 0.2), anvil);
    
    // Anvil hot spot
    float hotSpot = smoothstep(0.1, 0.05, length(anvilP));
    color += vec3(0.3, 0.1, 0.0) * hotSpot * flicker;
    
    // Dwarves (3 of them)
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        float dwarfX = -0.8 + fi * 0.8 + sin(t * 0.1 + fi) * 0.1;
        float dwarfY = -0.5 + abs(sin(t * 2.0 + fi)) * 0.05;
        
        vec2 dwarfP = p - vec2(dwarfX, dwarfY);
        
        // Body (stout)
        float body = length(dwarfP * vec2(1.0, 0.8)) - 0.18;
        body = smoothstep(0.02, 0.0, -body);
        
        // Head
        vec2 headP = dwarfP - vec2(0.0, 0.32);
        float head = length(headP) - 0.12;
        head = smoothstep(0.02, 0.0, -head);
        
        // Helmet
        vec2 helmetP = headP - vec2(0.0, 0.08);
        float helmet = length(helmetP) - 0.1;
        helmet = max(helmet, -helmetP.y - 0.02);
        helmet = smoothstep(0.02, 0.0, -helmet);
        
        // Beard
        vec2 beardP = dwarfP - vec2(0.0, 0.18);
        float beard = length(beardP) - 0.12;
        beard = smoothstep(0.02, 0.0, -beard);
        
        // Axe
        vec2 axeP = dwarfP - vec2(0.2, 0.0);
        float axeHandle = max(abs(axeP.x) - 0.015, abs(axeP.y + 0.1) - 0.15);
        vec2 bladeP = axeP - vec2(0.0, -0.22);
        float blade = max(abs(bladeP.x) - 0.08, abs(bladeP.y) - 0.05);
        float axe = min(smoothstep(0.02, 0.0, -axeHandle), smoothstep(0.02, 0.0, -blade));
        
        // Arms
        vec2 armLP = dwarfP - vec2(-0.18, 0.05);
        vec2 armRP = dwarfP - vec2(0.18, 0.05);
        float armL = length(armLP) - 0.05;
        float armR = length(armRP) - 0.05;
        float arms = max(smoothstep(0.02, 0.0, -armL), smoothstep(0.02, 0.0, -armR));
        
        float dwarf = body;
        dwarf = max(dwarf, head);
        dwarf = max(dwarf, helmet);
        dwarf = max(dwarf, beard);
        dwarf = max(dwarf, axe);
        dwarf = max(dwarf, arms);
        
        // Colors
        vec3 dwarfColor = vec3(0.6, 0.45, 0.35); // Skin
        dwarfColor = mix(dwarfColor, vec3(0.4, 0.3, 0.2), beard); // Beard
        dwarfColor = mix(dwarfColor, vec3(0.3, 0.25, 0.2), helmet); // Helmet
        dwarfColor = mix(dwarfColor, vec3(0.5, 0.4, 0.35), axe); // Axe
        
        // Forge lighting
        float dwarfLight = 1.0 / (1.0 + length(p - forgePos) * 0.5);
        dwarfColor *= (0.3 + dwarfLight * 3.0 * flicker);
        
        color = mix(color, dwarfColor, dwarf);
    }
    
    // Stone pillars
    for (float i = 0.0; i < 2.0; i++) {
        float fi = i;
        float pillarX = -1.0 + fi * 2.0;
        vec2 pillarP = p - vec2(pillarX, 0.0);
        float pillar = max(abs(pillarP.x) - 0.15, abs(pillarP.y + 0.2) - 0.8);
        pillar = smoothstep(0.02, 0.0, -pillar);
        color = mix(color, vec3(0.15, 0.12, 0.08), pillar * 0.5);
    }
    
    // Embers
    for (float i = 0.0; i < 10.0; i++) {
        float fi = i;
        vec2 emberPos = p + vec2(
            sin(t * 0.5 + fi) * 0.8,
            mod(t * 0.3 + fi * 0.2, 1.5) - 0.5
        );
        float ember = smoothstep(0.015, 0.0, length(emberPos));
        color += vec3(1.0, 0.3, 0.0) * ember * flicker * 0.3;
    }
    
    // Fog
    float fog = smoothstep(2.0, 0.5, length(p));
    color = mix(color, vec3(0.02, 0.01, 0.005), fog * 0.5);
    
    color *= intensity;
    return vec4(color, alpha);
}