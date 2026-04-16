// Orcs 3D - Volcanic Fortress with 3D Orc Warriors
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

using namespace ShaderUtils;

// Orc SDF
float orcSDF(float3 p, float time) {
    float d = 1e10;
    
    // Body (muscular, hunched)
    float3 bodyP = p - float3(0.0, -0.1, 0.0);
    float body = length(bodyP.xz * float2(1.3, 1.0)) - 0.28;
    body = max(body, abs(bodyP.y) - 0.35);
    
    // Head (large jaw, underbite)
    float3 headP = p - float3(0.0, 0.35, 0.05);
    float head = sdSphere(headP, 0.18);
    // Jaw protrusion
    float3 jawP = p - float3(0.0, 0.25, 0.15);
    float jaw = sdBox(jawP, float3(0.12, 0.1, 0.1));
    // Tusks
    float3 tuskLP = p - float3(-0.08, 0.2, 0.2);
    float3 tuskRP = p - float3(0.08, 0.2, 0.2);
    float tuskL = sdBox(tuskLP, float3(0.03, 0.08, 0.03));
    float tuskR = sdBox(tuskRP, float3(0.03, 0.08, 0.03));
    
    // Heavy brow ridge
    float3 browP = p - float3(0.0, 0.42, 0.12);
    float brow = sdBox(browP, float3(0.15, 0.04, 0.06));
    
    // Shoulder armor (spiked)
    float3 shoulderLP = p - float3(-0.35, 0.05, 0.0);
    float3 shoulderRP = p - float3(0.35, 0.05, 0.0);
    float shoulderL = length(shoulderLP) - 0.12;
    float shoulderR = length(shoulderRP) - 0.12;
    // Spikes on shoulders
    float3 spikeLP = p - float3(-0.45, 0.15, 0.0);
    float3 spikeRP = p - float3(0.45, 0.15, 0.0);
    float spikeL = sdBox(spikeLP, float3(0.04, 0.1, 0.04));
    float spikeR = sdBox(spikeRP, float3(0.04, 0.1, 0.04));
    
    // Arms with battle axe
    float3 armLP = p - float3(-0.32, -0.15, 0.05);
    float armL = length(armLP) - 0.1;
    
    // Giant battle axe in right hand
    float3 axeP = p - float3(0.4, -0.25, 0.25);
    // Axe handle
    float3 handleP = axeP;
    handleP.y += 0.3;
    float handle = length(handleP.xz) - 0.04;
    handle = max(handle, abs(handleP.y - 0.3) - 0.4);
    // Axe blade (double-bitted)
    float3 bladeP = axeP - float3(0.0, 0.35, 0.0);
    float blade1 = sdBox(bladeP - float3(0.1, 0.0, 0.0), float3(0.15, 0.12, 0.03));
    float blade2 = sdBox(bladeP + float3(0.1, 0.0, 0.0), float3(0.15, 0.12, 0.03));
    float axeBlade = min(blade1, blade2);
    float axe = min(handle, axeBlade);
    
    // Legs
    float3 legLP = p - float3(-0.15, -0.55, 0.0);
    float3 legRP = p - float3(0.15, -0.55, 0.0);
    float legL = length(legLP.xz) - 0.12;
    legL = max(legL, abs(legLP.y) - 0.25);
    float legR = length(legRP.xz) - 0.12;
    legR = max(legR, abs(legRP.y) - 0.25);
    
    d = min(body, head);
    d = min(d, jaw);
    d = min(d, tuskL);
    d = min(d, tuskR);
    d = min(d, brow);
    d = min(d, shoulderL);
    d = min(d, shoulderR);
    d = min(d, spikeL);
    d = min(d, spikeR);
    d = min(d, armL);
    d = min(d, axe);
    d = min(d, legL);
    d = min(d, legR);
    
    return d;
}

float map(float3 p, float time) {
    float d = p.y + 1.2; // Lava floor
    
    // Fortress walls (more detailed)
    float3 wallP = p;
    float walls = -sdBox(wallP, float3(6.0, 5.0, 8.0));
    
    // Spiky pillars with more detail
    for(int i = 0; i < 6; i++) {
        float fi = float(i);
        float3 pillP = p;
        pillP.xz = mod(pillP.xz + fi * 1.5, 5.0) - 2.5;
        
        // Main pillar
        float pill = length(pillP.xz) - 0.35;
        pill = max(pill, abs(pillP.y + 0.5) - 2.0);
        
        // Spikes on pillar
        for(int j = 0; j < 4; j++) {
            float fj = float(j);
            float3 spikeP = pillP - float3(
                cos(fj * 1.57) * 0.4,
                -1.0 + fj * 0.6,
                sin(fj * 1.57) * 0.4
            );
            float spike = length(spikeP.xyz) - 0.08;
            spike = max(spike, abs(spikeP.y) - 0.15);
            pill = min(pill, spike);
        }
        
        d = min(d, pill);
    }
    
    // Orc warriors
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 orcPos = float3(
            -2.0 + fi * 2.0 + sin(time * 0.2 + fi) * 0.3,
            -1.2 + abs(sin(time * 1.5 + fi)) * 0.05, // Stomping
            -3.0 + fi * 0.5
        );
        
        float3 oP = p - orcPos;
        // Face camera with slight variation
        float angle = sin(time * 0.1 + fi) * 0.3;
        float2 rotP = float2(
            oP.x * cos(angle) - oP.z * sin(angle),
            oP.x * sin(angle) + oP.z * cos(angle)
        );
        oP.x = rotP.x;
        oP.z = rotP.y;
        
        float orc = orcSDF(oP, time + fi);
        d = min(d, orc);
    }
    
    // Fortress gate
    float3 gateP = p - float3(0.0, -0.5, 4.0);
    float gate = sdBox(gateP, float3(2.0, 1.5, 0.3));
    // Portcullis bars
    float barPattern = step(0.5, fract(gateP.x * 4.0));
    gate = max(gate, -(barPattern * 0.1));
    d = min(d, gate);
    
    return min(d, walls);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float flicker = 0.7 + 0.3 * sin(t*15.0) * sin(t*23.0);
    float3 ro = float3(3.0 * sin(t*0.3), 1.5 + sin(t*0.2)*0.3, -5.0);
    float3 rd = normalize(float3(uv, 1.0));
    rd = lookAt(ro, float3(0, -0.5, 0)) * rd;
    
    float dTotal = 0.0;
    float d;
    float3 accumulatedGlow = float3(0.0);
    
    for(int i = 0; i < 80; i++) {
        float3 p = ro + rd * dTotal;
        d = map(p, t);
        
        // Lava glow accumulation
        float lavaDist = p.y + 1.2;
        accumulatedGlow += float3(1.0, 0.15, 0.0) * 0.03 / (1.0 + lavaDist * lavaDist * 2.0);
        
        if(d < 0.001 || dTotal > 25.0) break;
        dTotal += d * 0.7;
    }
    
    float3 color = float3(0.08, 0.01, 0.0); // Dark red volcanic sky
    
    if(dTotal < 25.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        // Multiple lava light sources
        float3 lp1 = float3(0, -1.5, 0); // Main lava pit
        float3 lp2 = float3(3.0, -1.2, -2.0); // Side lava flow
        float3 lp3 = float3(-3.0, -1.0, 1.0); // Another lava flow
        
        
        float diff1 = max(dot(n, normalize(p-lp1)), 0.0);
        float diff2 = max(dot(n, normalize(p-lp2)), 0.0) * 0.5;
        float diff3 = max(dot(n, normalize(p-lp3)), 0.0) * 0.5;
        
        float atten1 = 1.0 / (1.0 + length(p-lp1) * 0.3);
        float atten2 = 1.0 / (1.0 + length(p-lp2) * 0.5);
        float atten3 = 1.0 / (1.0 + length(p-lp3) * 0.5);
        
        // Material detection
        float3 baseColor = float3(0.15, 0.08, 0.05); // Stone default
        
        // Orc skin and armor
        for(int i = 0; i < 3; i++) {
            float fi = float(i);
            float3 orcPos = float3(
                -2.0 + fi * 2.0,
                -1.2,
                -3.0 + fi * 0.5
            );
            
            if(length(p - orcPos) < 0.7) {
                // Green orc skin
                baseColor = float3(0.2, 0.5, 0.15);
                
                // Tusks
                if(p.z > orcPos.z + 0.18 && abs(p.x - orcPos.x) > 0.06 && p.y < orcPos.y + 0.25) {
                    baseColor = float3(0.9, 0.85, 0.75); // Bone white
                }
                
                // Armor
                if(abs(p.x - orcPos.x) > 0.3 && p.y > orcPos.y) {
                    baseColor = float3(0.15, 0.12, 0.1); // Dark metal
                }
                
                // Axe blade
                if(p.x > orcPos.x + 0.3 && p.y > orcPos.y - 0.3) {
                    baseColor = float3(0.6, 0.55, 0.5); // Steel
                    // Add blood stains
                    float blood = snoise(p * 10.0);
                    if(blood > 0.6) baseColor = float3(0.4, 0.05, 0.0);
                }
            }
        }
        
        // Lava
        if(p.y < -1.1) {
            baseColor = float3(1.0, 0.1 + flicker * 0.2, 0.0);
            float lavaNoise = snoise(p.xz * 3.0 + t);
            baseColor += float3(0.2, 0.1, 0.0) * lavaNoise;
        }
        
        // War paint markings on walls
        float paintPattern = snoise(p * 4.0 + t * 0.1);
        if(paintPattern > 0.7 && p.y > -0.5) {
            baseColor = mix(baseColor, float3(0.6, 0.05, 0.0), 0.6);
        }
        
        float3 lavaLight = float3(1.0, 0.2, 0.0) * flicker;
        color = baseColor * 0.1; // Ambient
        color += baseColor * diff1 * lavaLight * atten1 * 8.0;
        color += baseColor * diff2 * lavaLight * atten2 * 4.0;
        color += baseColor * diff3 * lavaLight * atten3 * 4.0;
    }
    
    // Add accumulated lava glow
    color += accumulatedGlow * flicker;
    
    // Smoke/ash particles
    for(int i = 0; i < 20; i++) {
        float fi = float(i);
        float2 ashUV = uv + float2(
            sin(t * 0.3 + fi) * 0.8,
            t * 0.2 + fi * 0.1
        );
        float ash = smoothstep(0.015, 0.0, length(ashUV));
        color += float3(0.4, 0.3, 0.25) * ash * (0.3 + 0.2 * sin(t * 2.0 + fi));
    }
    
    // Volcanic ash fog
    float3 fogColor = float3(0.15, 0.05, 0.02);
    color = mix(color, fogColor, 1.0 - exp(-dTotal * 0.1));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}