// Dwarves 3D - Underground Forge with 3D Dwarves
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

using namespace ShaderUtils;

// Dwarf SDF
float dwarfSDF(float3 p, float time) {
    float d = 1e10;
    
    // Body (stout cylinder)
    float3 bodyP = p - float3(0.0, -0.1, 0.0);
    float body = length(bodyP.xz) - 0.25;
    body = max(body, abs(bodyP.y) - 0.3);
    
    // Head
    float3 headP = p - float3(0.0, 0.3, 0.0);
    float head = sdSphere(headP, 0.18);
    
    // Helmet
    float3 helmetP = p - float3(0.0, 0.4, 0.0);
    float helmet = sdSphere(helmetP, 0.15);
    helmet = max(helmet, -p.y + 0.4); // Cut bottom
    helmet = max(helmet, p.z - 0.05); // Flatten front
    
    // Beard (volumetric shape)
    float3 beardP = p - float3(0.0, 0.15, 0.12);
    float beard = length(beardP.xz) - 0.15;
    beard = max(beard, abs(beardP.y + 0.1) - 0.15);
    beard += sin(p.x * 10.0 + time) * 0.02; // Animated beard
    
    // Arms
    float3 armLP = p - float3(-0.3, -0.05, 0.1);
    float3 armRP = p - float3(0.3, -0.05, 0.1);
    float armL = length(armLP) - 0.08;
    float armR = length(armRP) - 0.08;
    
    // Axe (held in right hand)
    float3 axeP = p - float3(0.35, -0.05, 0.15);
    // Axe handle
    float handle = length(axeP.xz) - 0.03;
    handle = max(handle, abs(axeP.y + 0.15) - 0.25);
    // Axe blade
    float3 bladeP = axeP - float3(0.0, -0.35, 0.0);
    float blade = sdBox(bladeP, float3(0.12, 0.08, 0.02));
    float axe = min(handle, blade);
    
    // Legs
    float3 legLP = p - float3(-0.12, -0.5, 0.0);
    float3 legRP = p - float3(0.12, -0.5, 0.0);
    float legL = length(legLP.xz) - 0.08;
    legL = max(legL, abs(legLP.y) - 0.2);
    float legR = length(legRP.xz) - 0.08;
    legR = max(legR, abs(legRP.y) - 0.2);
    
    d = min(body, head);
    d = min(d, helmet);
    d = min(d, beard);
    d = min(d, armL);
    d = min(d, armR);
    d = min(d, axe);
    d = min(d, legL);
    d = min(d, legR);
    
    return d;
}

float map(float3 p, float time) {
    float d = 1e10;
    
    // Cave walls (infinitely repeating box cutout)
    float3 caveP = p;
    float cave = -sdBox(caveP, float3(3.0, 2.5, 15.0));
    
    // Stone pillars
    float3 pillP = p;
    pillP.xz = mod(pillP.xz + 2.0, 6.0) - 3.0;
    float pill = sdBox(pillP, float3(0.6, 3.0, 0.6));
    
    // Anvil with more detail
    float3 anvilBaseP = p - float3(0.0, -0.6, -1.0);
    float anvilBase = sdBox(anvilBaseP, float3(0.4, 0.15, 0.25));
    float3 anvilTopP = p - float3(0.0, -0.4, -1.0);
    float anvilTop = sdBox(anvilTopP, float3(0.25, 0.1, 0.15));
    float anvil = min(anvilBase, anvilTop);
    
    // Multiple dwarves at work
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 dwarfPos = float3(
            sin(fi * 2.5 + time * 0.1) * 1.5,
            -0.8 + abs(sin(time * 2.0 + fi)) * 0.05, // Hammering motion
            -2.0 + fi * 1.5
        );
        
        float3 dP = p - dwarfPos;
        // Rotate dwarves to face center
        float angle = atan2(dwarfPos.x, dwarfPos.z);
        float2 rotP = float2(
            dP.x * cos(angle) - dP.z * sin(angle),
            dP.x * sin(angle) + dP.z * cos(angle)
        );
        dP.x = rotP.x;
        dP.z = rotP.y;
        
        float dwarf = dwarfSDF(dP, time + fi);
        d = min(d, dwarf);
    }
    
    // Forge/furnace
    float3 forgeP = p - float3(0.0, -1.0, 2.0);
    float forge = sdBox(forgeP, float3(1.0, 0.8, 0.5));
    // Cut out fire opening
    float fireHole = sdBox(forgeP + float3(0.0, 0.3, -0.4), float3(0.6, 0.4, 0.1));
    forge = max(forge, -fireHole);
    
    d = min(d, cave);
    d = min(d, pill);
    d = min(d, anvil);
    d = min(d, forge);
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    float2 mouse = uniforms.mouse / uniforms.resolution.xy * 2.0 - 1.0;
    float3 ro = float3(
        mouse.x * 3.0,
        0.5 + mouse.y * 1.0,
        -4.0
    );
    float3 rd = normalize(float3(uv, 1.2));
    
    float td = 0.0;
    float d;
    float3 accumulatedEmissive = float3(0.0);
    
    for(int i = 0; i < 80; i++) {
        float3 p = ro + rd * td;
        d = map(p, t);
        
        // Forge glow accumulation
        float3 forgeP = p - float3(0.0, -1.0, 2.0);
        float fireDist = length(forgeP + float3(0.0, 0.3, -0.4));
        accumulatedEmissive += float3(1.0, 0.3, 0.05) * 0.02 / (1.0 + fireDist * 2.0);
        
        if(d < 0.001 || td > 25.0) break;
        td += d * 0.7;
    }
    
    float3 color = float3(0.03, 0.02, 0.01); // Dark cave
    
    if(td < 25.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        // Multiple light sources
        // Main forge light (flickering orange)
        float3 lp1 = float3(0.0, -0.3, 1.5);
        float flicker = 0.8 + 0.2 * sin(t * 25.0) + 0.1 * sin(t * 50.0);
        float3 lightCol1 = float3(1.0, 0.35, 0.05) * flicker;
        
        // Ambient torch lights
        float3 lp2 = float3(2.0, 0.5, -1.0);
        float3 lightCol2 = float3(0.8, 0.4, 0.1);
        
        float3 toLight1 = normalize(lp1 - p);
        float3 toLight2 = normalize(lp2 - p);
        
        float diff1 = max(dot(n, toLight1), 0.0);
        float diff2 = max(dot(n, toLight2), 0.0) * 0.3;
        
        float atten1 = 1.0 / (1.0 + length(lp1 - p) * 0.5);
        float atten2 = 1.0 / (1.0 + length(lp2 - p) * 0.3);
        
        // Material detection
        float3 baseColor = float3(0.15, 0.12, 0.08); // Stone default
        
        // Dwarf skin
        float3 checkDwarf = p - float3(0.0, -0.8, 0.0);
        for(int i = 0; i < 3; i++) {
            float fi = float(i);
            float3 dwarfPos = float3(
                sin(fi * 2.5 + t * 0.1) * 1.5,
                -0.8,
                -2.0 + fi * 1.5
            );
            if(length(p - dwarfPos) < 0.5) {
                baseColor = float3(0.6, 0.45, 0.35); // Skin
                // Beard area
                if(p.y < dwarfPos.y + 0.2 && p.z > dwarfPos.z + 0.1) {
                    baseColor = float3(0.4, 0.3, 0.2); // Brown beard
                }
                // Helmet
                if(p.y > dwarfPos.y + 0.35) {
                    baseColor = float3(0.3, 0.25, 0.2); // Metal helmet
                }
            }
        }
        
        // Anvil metal
        if(abs(p.y + 0.5) < 0.3 && abs(p.z + 1.0) < 0.5) {
            baseColor = float3(0.25, 0.22, 0.2); // Dark metal
            // Hot spot on anvil
            if(length(p - float3(0.0, -0.4, -1.0)) < 0.15) {
                baseColor += float3(0.3, 0.1, 0.0) * flicker;
            }
        }
        
        // Lava/glowing areas
        if(p.y < -0.9 && p.z > 1.5 && abs(p.x) < 0.6) {
            baseColor = float3(1.0, 0.15, 0.0) * flicker;
        }
        
        color = baseColor * (diff1 * lightCol1 * atten1 * 3.0 + diff2 * lightCol2 * aten2);
        color += baseColor * 0.05; // Ambient
        
        // Add glowing embers in air
        float emberNoise = snoise(p * 3.0 + t);
        color += float3(1.0, 0.3, 0.0) * max(0.0, emberNoise) * flicker * 0.3;
    }
    
    color += accumulatedEmissive;
    
    // Atmospheric fog
    color = mix(color, float3(0.02, 0.01, 0.005), 1.0 - exp(-td * 0.15));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}