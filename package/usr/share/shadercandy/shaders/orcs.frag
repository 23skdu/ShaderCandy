#include "base/common.glsl"

// orcs - Volcanic fortress with orc warriors

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Dark volcanic sky
    vec3 color = vec3(0.08, 0.01, 0.0);
    
    // Lava flicker
    float flicker = 0.7 + 0.3 * sin(t * 15.0) * sin(t * 23.0);
    
    // Lava glow (ground)
    float lavaDist = p.y + 0.8;
    vec3 lavaGlow = vec3(1.0, 0.15, 0.0) * 0.5 / (1.0 + lavaDist * lavaDist * 2.0);
    color += lavaGlow * flicker;
    
    // Ground (lava pit)
    if (p.y < -0.7) {
        vec3 lavaColor = vec3(1.0, 0.1 + flicker * 0.2, 0.0);
        float lavaNoise = noise(p * 5.0 + t * 0.5);
        color = mix(lavaColor, lavaColor * 1.3, lavaNoise * 0.5);
    }
    
    // Fortress walls (background)
    float wallLeft = smoothstep(-1.5, -0.8, p.x) * smoothstep(-3.0, -1.5, p.x);
    float wallRight = smoothstep(1.5, 0.8, p.x) * smoothstep(3.0, 1.5, p.x);
    float wallTop = smoothstep(0.5, 0.0, p.y);
    vec3 wallColor = mix(vec3(0.12, 0.08, 0.05), vec3(0.08, 0.05, 0.03), noise(p * 10.0));
    color = mix(color, wallColor, (wallLeft + wallRight) * wallTop);
    
    // Spiky pillars
    for (float i = 0.0; i < 6.0; i++) {
        float fi = i;
        float pillarX = -2.0 + mod(fi * 1.5 + 1.5, 5.0) - 2.5;
        
        vec2 pillarP = p - vec2(pillarX, -0.5);
        float pillar = length(pillarP.x) - 0.25;
        pillar = max(pillar, abs(pillarP.y + 0.3) - 1.2);
        
        // Spikes on top
        for (float j = 0.0; j < 4.0; j++) {
            float fj = j;
            vec2 spikeP = pillarP - vec2(cos(fj * 1.57) * 0.35, 0.5 + fj * 0.4);
            float spike = length(spikeP) - 0.08;
            pillar = min(pillar, spike);
        }
        
        pillar = smoothstep(0.02, 0.0, -pillar);
        color = mix(color, vec3(0.1, 0.06, 0.04), pillar);
    }
    
    // Orc warriors (3 of them)
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        float orcX = -1.5 + fi * 1.5 + sin(t * 0.2 + fi) * 0.2;
        float orcY = -0.65 + abs(sin(t * 1.5 + fi)) * 0.08;
        
        vec2 orcP = p - vec2(orcX, orcY);
        
        // Body
        float body = length(orcP * vec2(1.2, 1.0)) - 0.22;
        body = smoothstep(0.02, 0.0, -body);
        
        // Head
        vec2 headP = orcP - vec2(0.0, 0.35);
        float head = length(headP) - 0.15;
        head = smoothstep(0.02, 0.0, -head);
        
        // Jaw
        vec2 jawP = orcP - vec2(0.0, 0.25);
        float jaw = max(abs(jawP.x) - 0.1, abs(jawP.y + 0.05) - 0.08);
        jaw = smoothstep(0.02, 0.0, -jaw);
        
        // Tusks
        float tuskL = length(orcP - vec2(-0.06, 0.2)) - 0.04;
        float tuskR = length(orcP - vec2(0.06, 0.2)) - 0.04;
        float tusks = max(smoothstep(0.01, 0.0, -tuskL), smoothstep(0.01, 0.0, -tuskR));
        
        // Brow ridge
        vec2 browP = headP - vec2(0.0, 0.08);
        float brow = max(abs(browP.x) - 0.12, abs(browP.y) - 0.03);
        brow = smoothstep(0.02, 0.0, -brow);
        
        // Shoulders
        vec2 shoulderLP = orcP - vec2(-0.28, 0.1);
        vec2 shoulderRP = orcP - vec2(0.28, 0.1);
        float shoulder = length(shoulderLP) - 0.1;
        shoulder = max(shoulder, length(shoulderRP) - 0.1);
        shoulder = smoothstep(0.02, 0.0, -shoulder);
        float shoulder = length(shoulderP) - 0.1;
        shoulder = smoothstep(0.02, 0.0, -shoulder);
        
        // Battle axe
        vec2 axeP = orcP - vec2(0.32, -0.15);
        float axeHandle = max(abs(axeP.x) - 0.02, abs(axeP.y + 0.2) - 0.3);
        vec2 bladeP = axeP - vec2(0.0, 0.15);
        float blade1 = max(abs(bladeP.x - 0.1) - 0.1, abs(bladeP.y) - 0.1);
        float blade2 = max(abs(bladeP.x + 0.1) - 0.1, abs(bladeP.y) - 0.1);
        float axe = min(smoothstep(0.02, 0.0, -axeHandle), 
                       min(smoothstep(0.02, 0.0, -blade1), smoothstep(0.02, 0.0, -blade2)));
        
        // Combine orc
        float orc = body;
        orc = max(orc, head);
        orc = max(orc, jaw);
        orc = max(orc, brow);
        orc = max(orc, shoulder);
        orc = max(orc, axe);
        
        // Orc skin color (green)
        vec3 orcColor = vec3(0.2, 0.5, 0.15);
        
        // Tusks (bone white)
        orcColor = mix(orcColor, vec3(0.9, 0.85, 0.75), tusks);
        
        // Metal armor
        orcColor = mix(orcColor, vec3(0.15, 0.12, 0.1), shoulder * 0.8);
        
        // Axe (steel)
        orcColor = mix(orcColor, vec3(0.6, 0.55, 0.5), axe);
        
        // Lava lighting
        float orcLight = 1.0 / (1.0 + length(p - vec2(orcX, -0.7)));
        orcColor *= (0.3 + orcLight * 2.0 * flicker);
        
        color = mix(color, orcColor, orc);
    }
    
    // Smoke/ash particles
    for (float i = 0.0; i < 15.0; i++) {
        float fi = i;
        vec2 ashPos = p + vec2(
            sin(t * 0.3 + fi) * 0.8,
            mod(t * 0.15 + fi * 0.1, 2.0) - 1.0
        );
        float ash = smoothstep(0.02, 0.0, length(ashPos));
        color += vec3(0.4, 0.3, 0.25) * ash * (0.3 + 0.2 * sin(t * 2.0 + fi));
    }
    
    // Vignette
    color *= smoothstep(1.5, 0.5, length(p));
    
    color *= intensity;
    return vec4(color, alpha);
}