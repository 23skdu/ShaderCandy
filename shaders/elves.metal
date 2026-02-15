// Elves 3D - Mystical Forest with 3D Elves
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

using namespace ShaderUtils;

// Elf SDF
float elfSDF(float3 p, float time) {
    float d = 1e10;
    
    // Body (slender)
    float3 bodyP = p - float3(0.0, 0.1, 0.0);
    float body = length(bodyP.xz * float2(0.8, 1.0)) - 0.12;
    body = max(body, abs(bodyP.y) - 0.25);
    
    // Head (slender with pointed ears)
    float3 headP = p - float3(0.0, 0.45, 0.0);
    float head = sdSphere(headP, 0.1);
    
    // Pointed ears
    float3 earLP = p - float3(-0.12, 0.45, 0.0);
    float3 earRP = p - float3(0.12, 0.45, 0.0);
    // Rotate ears outward
    float2 earRotL = float2(earLP.x * 0.7 - earLP.y * 0.7, earLP.x * 0.7 + earLP.y * 0.7);
    earLP.x = earRotL.x;
    earLP.y = earRotL.y;
    float2 earRotR = float2(earRP.x * 0.7 + earRP.y * 0.7, -earRP.x * 0.7 + earRP.y * 0.7);
    earRP.x = earRotR.x;
    earRP.y = earRotR.y;
    
    float earL = sdBox(earLP, float3(0.03, 0.08, 0.02));
    float earR = sdBox(earRP, float3(0.03, 0.08, 0.02));
    
    // Hair (flowing)
    float3 hairP = p - float3(0.0, 0.5, -0.05);
    float hair = length(hairP.xz) - 0.12;
    hair = max(hair, -p.y + 0.4);
    hair += sin(p.x * 8.0 + time * 2.0) * 0.01; // Flowing animation
    
    // Arms holding bow
    float3 armLP = p - float3(-0.18, 0.15, 0.1);
    float3 armRP = p - float3(0.18, 0.15, 0.1);
    float armL = length(armLP) - 0.06;
    float armR = length(armRP) - 0.06;
    
    // Bow
    float3 bowP = p - float3(0.0, 0.15, 0.25);
    // Curved bow shape
    float bowCurve = length(bowP.xy - float2(0.0, 0.0)) - 0.25;
    bowCurve = abs(bowCurve) - 0.02;
    bowCurve = max(bowCurve, abs(bowP.z) - 0.02);
    bowCurve = max(bowCurve, -bowP.z + 0.2); // Only front curve
    
    // Bow string
    float3 stringP = p - float3(0.0, 0.15, 0.23);
    float bowString = length(stringP.xy) - 0.22;
    bowString = abs(bowString) - 0.005;
    bowString = max(bowString, abs(stringP.z) - 0.01);
    
    float bow = min(bowCurve, bowString);
    
    // Legs
    float3 legLP = p - float3(-0.08, -0.3, 0.0);
    float3 legRP = p - float3(0.08, -0.3, 0.0);
    float legL = length(legLP.xz) - 0.05;
    legL = max(legL, abs(legLP.y) - 0.2);
    float legR = length(legRP.xz) - 0.05;
    legR = max(legR, abs(legRP.y) - 0.2);
    
    d = min(body, head);
    d = min(d, earL);
    d = min(d, earR);
    d = min(d, hair);
    d = min(d, armL);
    d = min(d, armR);
    d = min(d, bow);
    d = min(d, legL);
    d = min(d, legR);
    
    return d;
}

float map(float3 p, float time) {
    float d = p.y + 0.8; // ground
    
    // Forest trees with canopies
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float3 treeOffset = float3(
            sin(fi * 1.3) * 3.0,
            0.0,
            cos(fi * 1.1) * 3.0 - 1.0
        );
        
        float3 treeP = p - treeOffset;
        treeP.xz = mod(treeP.xz + 3.0, 6.0) - 3.0;
        
        // Trunk
        float h = 0.6 + hash(treeP.xz) * 0.4;
        float tree = length(treeP.xz) - (0.08 + h * 0.05);
        tree = max(tree, abs(treeP.y - h * 0.5) - h * 0.5);
        
        // Canopy (leaves)
        float3 canopyP = treeP - float3(0.0, h, 0.0);
        float canopy = length(canopyP) - (0.4 + h * 0.2);
        canopy += snoise(canopyP * 3.0 + time * 0.1) * 0.05;
        
        d = min(d, min(tree, canopy));
    }
    
    // 3D Elves positioned in forest
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float3 elfPos = float3(
            sin(fi * 2.0 + time * 0.2) * 1.5,
            -0.8 + sin(time + fi) * 0.02, // Subtle breathing
            -1.0 + fi * 0.8 + cos(time * 0.3 + fi) * 0.3
        );
        
        float3 eP = p - elfPos;
        // Face different directions
        float angle = time * 0.1 + fi * 1.57;
        float2 rotP = float2(
            eP.x * cos(angle) - eP.z * sin(angle),
            eP.x * sin(angle) + eP.z * cos(angle)
        );
        eP.x = rotP.x;
        eP.z = rotP.y;
        
        float elf = elfSDF(eP, time + fi);
        d = min(d, elf);
    }
    
    // Floating magic wisps (fairies/elves)
    for(int i = 0; i < 6; i++) {
        float fi = float(i);
        float3 wispP = p - float3(
            sin(time * 0.5 + fi * 1.5) * 2.0,
            0.5 + cos(time * 0.3 + fi * 2.0) * 0.8,
            cos(time * 0.4 + fi) * 2.0
        );
        d = min(d, sdSphere(wispP, 0.04 + 0.02 * sin(time * 3.0 + fi)));
    }
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    float2 mouse = uniforms.mouse / uniforms.resolution.xy * 2.0 - 1.0;
    float3 ro = float3(mouse.x * 2.0, 1.0 + mouse.y, -4.0);
    float3 rd = normalize(float3(uv, 1.5));
    
    float td = 0.0;
    float d;
    float3 accumulatedGlow = float3(0.0);
    
    for(int i = 0; i < 100; i++) {
        float3 p = ro + rd * td;
        d = map(p, t);
        
        // Magic glow accumulation
        for(int j = 0; j < 6; j++) {
            float fj = float(j);
            float3 wispP = p - float3(
                sin(t * 0.5 + fj * 1.5) * 2.0,
                0.5 + cos(t * 0.3 + fj * 2.0) * 0.8,
                cos(t * 0.4 + fj) * 2.0
            );
            float wispDist = length(wispP);
            accumulatedGlow += float3(0.4, 0.9, 0.6) * 0.01 / (1.0 + wispDist * 3.0);
        }
        
        if(d < 0.001 || td > 25.0) break;
        td += d * 0.7;
    }
    
    float3 color = float3(0.005, 0.02, 0.01); // Deep enchanted forest
    
    if(td < 25.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        // Multiple light sources
        float3 lp1 = float3(2.0, 3.0, -2.0); // Moonlight
        float3 lp2 = float3(-1.0, 0.5, 1.0); // Magic glow
        
        float3 toLight1 = normalize(lp1 - p);
        float3 toLight2 = normalize(lp2 - p);
        
        float diff1 = max(dot(n, toLight1), 0.0);
        float diff2 = max(dot(n, toLight2), 0.0) * 0.5;
        
        // Material detection
        float3 baseColor = float3(0.08, 0.15, 0.06); // Default forest
        float emissive = 0.0;
        
        // Check if hitting elf
        for(int i = 0; i < 4; i++) {
            float fi = float(i);
            float3 elfPos = float3(
                sin(fi * 2.0 + t * 0.2) * 1.5,
                -0.8,
                -1.0 + fi * 0.8 + cos(t * 0.3 + fi) * 0.3
            );
            
            if(length(p - elfPos) < 0.6) {
                baseColor = float3(0.2, 0.5, 0.3); // Green tunic
                // Skin
                if(p.y > elfPos.y + 0.35 && p.y < elfPos.y + 0.5) {
                    baseColor = float3(0.85, 0.75, 0.65); // Fair skin
                }
                // Hair
                if(p.y > elfPos.y + 0.45 && p.z < elfPos.z - 0.05) {
                    baseColor = float3(0.9, 0.8, 0.4); // Golden hair
                }
                // Bow
                if(p.z > elfPos.z + 0.2 && abs(p.y - elfPos.y - 0.15) < 0.3) {
                    baseColor = float3(0.4, 0.25, 0.15); // Wood bow
                }
            }
        }
        
        // Trees
        if(p.y > 0.0) {
            // Canopy
            baseColor = mix(
                float3(0.05, 0.25, 0.08),
                float3(0.1, 0.4, 0.15),
                snoise(p * 2.0)
            );
        } else if (p.y > -0.5) {
            // Trunk
            baseColor = float3(0.2, 0.15, 0.1);
        }
        
        // Ground with moss
        if(p.y < -0.75) {
            baseColor = float3(0.1, 0.2, 0.08);
            // Mushrooms on ground
            float mushNoise = snoise(p.xz * 5.0);
            if(mushNoise > 0.6) {
                baseColor = float3(0.9, 0.8, 0.7); // Mushroom caps
            }
        }
        
        // Check wisps
        float distToWisp = 1e10;
        for(int i = 0; i < 6; i++) {
            float fi = float(i);
            float3 wispP = p - float3(
                sin(t * 0.5 + fi * 1.5) * 2.0,
                0.5 + cos(t * 0.3 + fi * 2.0) * 0.8,
                cos(t * 0.4 + fi) * 2.0
            );
            distToWisp = min(distToWisp, length(wispP));
        }
        
        if(distToWisp < 0.08) {
            baseColor = float3(0.3, 1.0, 0.5) * 2.0;
            emissive = 0.5;
        }
        
        color = baseColor * (diff1 * 0.8 + diff2 + 0.2);
        color += baseColor * emissive;
    }
    
    // Add accumulated magic glow
    color += accumulatedGlow;
    
    // Atmospheric fog/glow - enchanted forest atmosphere
    float3 fogColor = float3(0.05, 0.15, 0.1);
    color = mix(color, fogColor, 1.0 - exp(-td * 0.12));
    
    // Fireflies/particles
    for(int i = 0; i < 15; i++) {
        float fi = float(i);
        float2 fireflyUV = uv + float2(
            sin(t * 0.8 + fi * 3.0) * 0.5,
            cos(t * 0.6 + fi * 2.5) * 0.4 + fi * 0.1
        );
        float firefly = smoothstep(0.02, 0.0, length(fireflyUV));
        color += float3(0.5, 1.0, 0.3) * firefly * (0.5 + 0.5 * sin(t * 4.0 + fi * 2.0));
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}