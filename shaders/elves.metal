// Elves 3D - Enchanted Grove with 3D Elves (Redesigned)
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

float sdCylinder(float3 p, float2 h) {
    float2 d = abs(float2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float3 elfSDF(float3 p, float time, float variant) {
    float3 d = float3(1e10, 1e10, 0.0);
    
    float breathOffset = sin(time * 1.0 + variant * 1.8) * 0.01;
    float hairFlow = sin(time * 2.5 + p.y * 4.0 + variant) * 0.015;
    
    float3 bodyP = p - float3(0.0, 0.1 + breathOffset, 0.0);
    float body = length(bodyP.xz * float2(0.75, 1.0)) - 0.11;
    body = max(body, abs(bodyP.y) - 0.24);
    if(body < d.x) d = float3(body, 0.0, 1.0);
    
    float3 headP = p - float3(0.0, 0.43 + breathOffset * 0.5, 0.0);
    float head = sdSphere(headP, 0.095);
    if(head < d.x) d = float3(head, 0.0, 2.0);
    
    float3 earLP = p - float3(-0.1, 0.43 + breathOffset * 0.3, 0.0);
    float3 earRP = p - float3(0.1, 0.43 + breathOffset * 0.3, 0.0);
    float2 earRotL = float2(earLP.x * 0.65 - earLP.y * 0.75, earLP.x * 0.75 + earLP.y * 0.65);
    earLP.x = earRotL.x;
    earLP.y = earRotL.y;
    float2 earRotR = float2(earRP.x * 0.65 + earRP.y * 0.75, -earRP.x * 0.75 + earRP.y * 0.65);
    earRP.x = earRotR.x;
    earRP.y = earRotR.y;
    float earL = sdBox(earLP, float3(0.025, 0.09, 0.018));
    float earR = sdBox(earRP, float3(0.025, 0.09, 0.018));
    if(earL < d.x) d = float3(earL, 0.0, 3.0);
    if(earR < d.x) d = float3(earR, 0.0, 3.0);
    
    float3 hairP = p - float3(0.0, 0.48 + breathOffset * 0.2, -0.04);
    float hair = length(hairP.xz) - 0.11;
    hair = max(hair, -p.y + 0.38);
    hair += hairFlow;
    if(hair < d.x) d = float3(hair, 0.0, 4.0);
    
    float3 hairStrandP = p - float3(0.0, 0.35, -0.08);
    float hairStrand = sdBox(hairStrandP, float3(0.03, 0.15, 0.02));
    hairStrand = max(hairStrand, hairStrandP.z + 0.06);
    if(hairStrand < d.x) d = float3(hairStrand, 0.0, 4.0);
    
    float3 armLP = p - float3(-0.16 + breathOffset * 0.3, 0.14, 0.08);
    float3 armRP = p - float3(0.16 - breathOffset * 0.3, 0.14, 0.08);
    float armL = length(armLP) - 0.05;
    float armR = length(armRP) - 0.05;
    if(armL < d.x) d = float3(armL, 0.0, 1.0);
    if(armR < d.x) d = float3(armR, 0.0, 1.0);
    
    float3 bowP = p - float3(0.0, 0.14, 0.22);
    float bowCurve = length(bowP.xy) - 0.22;
    bowCurve = abs(bowCurve) - 0.018;
    bowCurve = max(bowCurve, abs(bowP.z) - 0.018);
    bowCurve = max(bowCurve, -bowP.z + 0.18);
    float3 stringP = p - float3(0.0, 0.14, 0.2);
    float bowString = length(stringP.xy) - 0.19;
    bowString = abs(bowString) - 0.004;
    bowString = max(bowString, abs(stringP.z) - 0.008);
    float bow = min(bowCurve, bowString);
    if(bow < d.x) d = float3(bow, 0.0, 5.0);
    
    float3 legLP = p - float3(-0.07, -0.28, 0.0);
    float3 legRP = p - float3(0.07, -0.28, 0.0);
    float legL = length(legLP.xz) - 0.045;
    legL = max(legL, abs(legLP.y) - 0.18);
    float legR = length(legRP.xz) - 0.045;
    legR = max(legR, abs(legRP.y) - 0.18);
    if(legL < d.x) d = float3(legL, 0.0, 1.0);
    if(legR < d.x) d = float3(legR, 0.0, 1.0);
    
    return d;
}

float3 map(float3 p, float time) {
    float3 result = float3(p.y + 0.75, 1e10, 10.0);
    
    for(int i = 0; i < 6; i++) {
        float fi = float(i);
        float windOffset = sin(time * 0.8 + fi * 0.7) * 0.03;
        float3 treeOffset = float3(
            sin(fi * 1.3 + time * 0.1) * 3.0 + windOffset,
            0.0,
            cos(fi * 1.1 + time * 0.08) * 3.0 - 1.0
        );
        
        float3 treeP = p - treeOffset;
        treeP.xz = mod(treeP.xz + 3.5, 7.0) - 3.5;
        
        float h = 0.5 + hash(treeP.xz + fi) * 0.5;
        float tree = length(treeP.xz) - (0.06 + h * 0.04);
        tree = max(tree, abs(treeP.y - h * 0.5) - h * 0.5);
        if(tree < result.x) result = float3(tree, 0.0, 11.0);
        
        float3 canopyP = treeP - float3(0.0, h, 0.0);
        float canopy = length(canopyP) - (0.35 + h * 0.18);
        canopy += snoise(canopyP * 2.5 + time * 0.15) * 0.06;
        if(canopy < result.x) result = float3(canopy, 0.0, 12.0);
        
        float3 flowerP = canopyP + float3(
            sin(fi * 2.1) * 0.15,
            0.2 + sin(time * 1.5 + fi) * 0.05,
            cos(fi * 1.7) * 0.15
        );
        float flower = sdSphere(flowerP, 0.04 + 0.02 * sin(time * 2.0 + fi));
        if(flower < result.x) result = float3(flower, 0.0, 13.0);
    }
    
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float3 elfPos = float3(
            sin(fi * 2.2 + time * 0.25) * 1.8,
            -0.75 + sin(time * 1.2 + fi * 1.5) * 0.025,
            -1.2 + fi * 0.9 + cos(time * 0.35 + fi) * 0.35
        );
        
        float3 eP = p - elfPos;
        float angle = time * 0.12 + fi * 1.57;
        float2 rotP = float2(
            eP.x * cos(angle) - eP.z * sin(angle),
            eP.x * sin(angle) + eP.z * cos(angle)
        );
        eP.x = rotP.x;
        eP.z = rotP.y;
        
        float3 elf = elfSDF(eP, time, fi);
        if(elf.x < result.x) result = float3(elf.x, elf.y, 20.0 + fi);
    }
    
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float3 wispP = p - float3(
            sin(time * 0.45 + fi * 1.7) * 2.5,
            0.4 + cos(time * 0.28 + fi * 2.2) * 0.9,
            cos(time * 0.35 + fi * 1.2) * 2.5
        );
        float wisp = sdSphere(wispP, 0.035 + 0.025 * sin(time * 3.5 + fi * 2.0));
        if(wisp < result.x) result = float3(wisp, 0.0, 14.0);
    }
    
    float3 moonP = p - float3(-3.0, 4.0, -5.0);
    float moon = sdSphere(moonP, 0.4);
    if(moon < result.x) result = float3(moon, 0.0, 15.0);
    
    float3 poolP = p - float3(2.0, -0.72, 1.0);
    float pool = sdBox(poolP, float3(0.8, 0.05, 0.6));
    if(pool < result.x) result = float3(pool, 0.0, 16.0);
    
    float3 stoneP = p - float3(-1.5, -0.6, 2.0);
    float stone = sdSphere(stoneP, 0.25);
    stone = max(stone, stoneP.y + 0.65);
    if(stone < result.x) result = float3(stone, 0.0, 17.0);
    
    float3 mushroomP = p - float3(0.8, -0.65, -0.5);
    float3 mushStem = sdCylinder(mushroomP.xzy, float2(0.03, 0.15));
    float3 capP = mushroomP - float3(0.0, 0.12, 0.0);
    float mushCap = sdBox(capP, float3(0.08, 0.04, 0.07));
    float mushroom = min(mushStem, mushCap);
    if(mushroom < result.x) result = float3(mushroom, 0.0, 18.0);
    
    return result;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    float2 mouse = uniforms.mouse / uniforms.resolution.xy * 2.0 - 1.0;
    float3 ro = float3(mouse.x * 2.5, 1.2 + mouse.y, -4.5);
    float3 rd = normalize(float3(uv, 1.4));
    
    float td = 0.0;
    float3 hitMaterial = float3(0.0);
    float3 accumulatedGlow = float3(0.0);
    float3 accumulatedMagic = float3(0.0);
    
    for(int i = 0; i < 120; i++) {
        float3 p = ro + rd * td;
        float3 mapResult = map(p, t);
        float d = mapResult.x;
        hitMaterial = mapResult;
        
        for(int j = 0; j < 8; j++) {
            float fj = float(j);
            float3 wispP = p - float3(
                sin(t * 0.45 + fj * 1.7) * 2.5,
                0.4 + cos(t * 0.28 + fj * 2.2) * 0.9,
                cos(t * 0.35 + fj * 1.2) * 2.5
            );
            float wispDist = length(wispP);
            float wispPulse = 0.7 + 0.3 * sin(t * 4.0 + fj * 3.0);
            float3 wispColor = float3(0.3 + fj * 0.08, 0.9 + fj * 0.02, 0.5 + fj * 0.05);
            accumulatedGlow += wispColor * 0.012 * wispPulse / (1.0 + wispDist * 2.5);
        }
        
        float3 moonPos = float3(-3.0, 4.0, -5.0);
        float moonDist = length(p - moonPos);
        float moonGlow = 0.6 + 0.2 * sin(t * 0.2);
        accumulatedMagic += float3(0.85, 0.9, 1.0) * 0.008 * moonGlow / (1.0 + moonDist * 0.3);
        
        float3 poolP = p - float3(2.0, -0.67, 1.0);
        if(abs(poolP.x) < 0.8 && abs(poolP.z) < 0.6 && poolP.y < 0.1) {
            float poolDist = length(poolP.xz);
            float ripple = sin(poolDist * 8.0 - t * 2.0) * 0.5 + 0.5;
            accumulatedGlow += float3(0.2, 0.5, 0.8) * 0.02 * ripple / (1.0 + poolDist);
        }
        
        if(d < 0.001 || td > 28.0) break;
        td += d * 0.65;
    }
    
    float3 color = float3(0.003, 0.015, 0.008);
    
    if(td < 28.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t).x - map(p - float3(0.01,0,0), t).x,
            map(p + float3(0,0.01,0), t).x - map(p - float3(0,0.01,0), t).x,
            map(p + float3(0,0,0.01), t).x - map(p - float3(0,0,0.01), t).x
        ));
        
        float3 lp1 = float3(-3.0, 4.0, -5.0);
        float3 lp2 = float3(2.0, 0.5, 1.0);
        float3 lp3 = float3(0.0, 2.0, 0.0);
        
        float3 toLight1 = normalize(lp1 - p);
        float3 toLight2 = normalize(lp2 - p);
        float3 toLight3 = normalize(lp3 - p);
        
        float diff1 = max(dot(n, toLight1), 0.0);
        float diff2 = max(dot(n, toLight2), 0.0) * 0.4;
        float diff3 = max(dot(n, toLight3), 0.0) * 0.3;
        
        float3 baseColor = float3(0.06, 0.12, 0.05);
        float3 emissive = float3(0.0);
        float ambientOcclusion = 1.0;
        
        int matId = int(hitMaterial.z);
        
        if(matId >= 20 && matId <= 24) {
            int elfIdx = matId - 20;
            float3 elfPos = float3(
                sin(float(elfIdx) * 2.2 + t * 0.25) * 1.8,
                -0.75,
                -1.2 + float(elfIdx) * 0.9 + cos(t * 0.35 + float(elfIdx)) * 0.35
            );
            
            baseColor = float3(0.15, 0.4, 0.22);
            
            if(p.y > elfPos.y + 0.32 && p.y < elfPos.y + 0.48) {
                float skinTone = 0.82 + 0.05 * sin(float(elfIdx));
                baseColor = float3(skinTone, skinTone * 0.92, skinTone * 0.85);
            }
            
            if(p.y > elfPos.y + 0.42 && p.z < elfPos.z - 0.02) {
                float hairHue = 0.85 + 0.1 * sin(float(elfIdx) * 1.5);
                baseColor = float3(hairHue, hairHue * 0.85, hairHue * 0.5);
            }
            
            if(p.z > elfPos.z + 0.18 && abs(p.y - elfPos.y - 0.14) < 0.28) {
                baseColor = float3(0.35, 0.22, 0.12);
            }
            
            ambientOcclusion = 0.75;
        }
        else if(matId == 11) {
            baseColor = float3(0.18, 0.12, 0.08);
        }
        else if(matId == 12) {
            float leafVar = snoise(p * 3.0 + t * 0.2);
            baseColor = mix(
                float3(0.04, 0.2, 0.06),
                float3(0.08, 0.35, 0.12),
                leafVar * 0.5 + 0.5
            );
            float leafGlow = snoise(p * 5.0 - t * 0.3);
            if(leafGlow > 0.6) {
                emissive += float3(0.1, 0.3, 0.1) * (leafGlow - 0.6) * 2.0;
            }
        }
        else if(matId == 13) {
            float flowerHue = snoise(p * 4.0) * 0.5 + 0.5;
            baseColor = mix(
                float3(0.9, 0.5, 0.6),
                float3(0.6, 0.3, 0.8),
                flowerHue
            );
            emissive += baseColor * 0.3;
        }
        else if(matId == 14) {
            float wispHue = snoise(p * 10.0 + t);
            float3 wispColor = mix(
                float3(0.2, 1.0, 0.4),
                float3(0.4, 0.8, 1.0),
                wispHue * 0.5 + 0.5
            );
            baseColor = wispColor * 1.5;
            emissive = wispColor * 2.0;
        }
        else if(matId == 15) {
            float moonPhase = sin(t * 0.1) * 0.5 + 0.5;
            baseColor = float3(0.9 + moonPhase * 0.1, 0.92, 0.95);
            float craterNoise = snoise(p * 8.0);
            baseColor = mix(baseColor, float3(0.7, 0.72, 0.75), craterNoise * 0.3);
            emissive = baseColor * 0.4;
        }
        else if(matId == 16) {
            float poolShimmer = snoise(p.xz * 6.0 - t * 0.5);
            baseColor = mix(
                float3(0.05, 0.15, 0.25),
                float3(0.1, 0.3, 0.5),
                poolShimmer * 0.5 + 0.5
            );
            emissive = float3(0.1, 0.25, 0.4) * (0.5 + 0.5 * sin(t * 1.5 + p.x * 3.0));
        }
        else if(matId == 17) {
            baseColor = float3(0.25, 0.22, 0.2);
            float mossPattern = snoise(p * 4.0);
            baseColor = mix(baseColor, float3(0.15, 0.25, 0.1), mossPattern * 0.5 + 0.5);
        }
        else if(matId == 18) {
            baseColor = float3(0.9, 0.85, 0.75);
            float capPattern = snoise(p * 8.0);
            baseColor = mix(baseColor, float3(0.8, 0.2, 0.15), capPattern * 0.5 + 0.5);
        }
        
        if(p.y < -0.7) {
            baseColor = float3(0.08, 0.16, 0.06);
            float mossGlow = snoise(p.xz * 6.0 + t * 0.1);
            if(mossGlow > 0.55) {
                baseColor = mix(baseColor, float3(0.15, 0.3, 0.1), (mossGlow - 0.55) * 3.0);
                emissive += float3(0.05, 0.15, 0.05) * (mossGlow - 0.55);
            }
        }
        
        float3 moonLight = float3(0.7, 0.75, 0.9);
        float3 magicLight = float3(0.3, 0.8, 0.5);
        float3 ambientLight = float3(0.08, 0.12, 0.1);
        
        color = baseColor * ambientLight * ambientOcclusion;
        color += baseColor * diff1 * moonLight * 1.0;
        color += baseColor * diff2 * magicLight * 0.8;
        color += baseColor * diff3 * magicLight * 0.6;
        color += emissive;
    }
    
    color += accumulatedGlow;
    color += accumulatedMagic;
    
    float3 fogColor = float3(0.04, 0.12, 0.08);
    color = mix(color, fogColor, 1.0 - exp(-td * 0.1));
    
    for(int i = 0; i < 20; i++) {
        float fi = float(i);
        float2 fireflyUV = uv + float2(
            sin(t * 0.75 + fi * 3.2) * 0.6,
            cos(t * 0.55 + fi * 2.8) * 0.45 + fi * 0.12
        );
        float firefly = smoothstep(0.022, 0.0, length(fireflyUV));
        float fireflyPulse = 0.4 + 0.6 * sin(t * 4.5 + fi * 2.5);
        float3 fireflyColor = mix(
            float3(0.5, 1.0, 0.3),
            float3(0.3, 0.8, 0.6),
            sin(fi * 1.3) * 0.5 + 0.5
        );
        color += fireflyColor * firefly * fireflyPulse;
    }
    
    float3 moonRays = float3(0.0);
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 rayUV = uv + float2(fi * 0.4 - 0.8, 0.0);
        float ray = smoothstep(0.08, 0.0, abs(rayUV.x)) * smoothstep(0.3, -0.5, rayUV.y);
        moonRays += float3(0.3, 0.35, 0.4) * ray * 0.15;
    }
    color += moonRays;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}