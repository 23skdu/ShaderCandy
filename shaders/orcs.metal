// Orcs 3D - Volcanic Fortress with 3D Orc Warriors (Redesigned)
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

float sdCylinder(float3 p, float2 h) {
    float2 d = abs(float2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float3 orcSDF(float3 p, float time, float variant) {
    float3 d = float3(1e10, 1e10, 0.0);
    
    float breathOffset = sin(time * 1.2 + variant * 2.0) * 0.015;
    float wobble = sin(time * 3.0 + p.y * 5.0) * 0.01;
    float3 wp = p + float3(wobble, 0.0, wobble * 0.5);
    
    float3 bodyP = wp - float3(0.0, -0.1 + breathOffset, 0.0);
    float body = length(bodyP.xz * float2(1.3, 1.0)) - 0.28;
    body = max(body, abs(bodyP.y) - 0.35);
    if(body < d.x) d = float3(body, 0.0, 1.0);
    
    float3 headP = wp - float3(0.0, 0.35, 0.05);
    float head = sdSphere(headP, 0.18);
    if(head < d.x) d = float3(head, 0.0, 2.0);
    
    float3 jawP = wp - float3(0.0, 0.25 + breathOffset * 0.5, 0.15);
    float jaw = sdBox(jawP, float3(0.12, 0.1, 0.1));
    if(jaw < d.x) d = float3(jaw, 0.0, 2.0);
    
    float3 tuskLP = wp - float3(-0.08, 0.2 + breathOffset * 0.3, 0.2);
    float3 tuskRP = wp - float3(0.08, 0.2 + breathOffset * 0.3, 0.2);
    float tuskL = sdBox(tuskLP, float3(0.03, 0.08, 0.03));
    float tuskR = sdBox(tuskRP, float3(0.03, 0.08, 0.03));
    float tusks = min(tuskL, tuskR);
    if(tusks < d.x) d = float3(tusks, 0.0, 3.0);
    
    float3 browP = wp - float3(0.0, 0.42, 0.12);
    float brow = sdBox(browP, float3(0.15, 0.04, 0.06));
    if(brow < d.x) d = float3(brow, 0.0, 2.0);
    
    float3 shoulderLP = wp - float3(-0.35, 0.05 + breathOffset * 0.5, 0.0);
    float3 shoulderRP = wp - float3(0.35, 0.05 + breathOffset * 0.5, 0.0);
    float shoulderL = length(shoulderLP) - 0.12;
    float shoulderR = length(shoulderRP) - 0.12;
    if(shoulderL < d.x) d = float3(shoulderL, 0.0, 4.0);
    if(shoulderR < d.x) d = float3(shoulderR, 0.0, 4.0);
    
    float3 spikeLP = wp - float3(-0.45, 0.15 + breathOffset * 0.8, 0.0);
    float3 spikeRP = wp - float3(0.45, 0.15 + breathOffset * 0.8, 0.0);
    float spikeL = sdBox(spikeLP, float3(0.04, 0.1, 0.04));
    float spikeR = sdBox(spikeRP, float3(0.04, 0.1, 0.04));
    if(spikeL < d.x) d = float3(spikeL, 0.0, 5.0);
    if(spikeR < d.x) d = float3(spikeR, 0.0, 5.0);
    
    float3 armLP = wp - float3(-0.32, -0.15 + breathOffset * 0.4, 0.05);
    float armL = length(armLP) - 0.1;
    if(armL < d.x) d = float3(armL, 0.0, 1.0);
    
    float3 axeP = wp - float3(0.4, -0.25, 0.25);
    float3 handleP = axeP;
    handleP.y += 0.3;
    float handle = length(handleP.xz) - 0.04;
    handle = max(handle, abs(handleP.y - 0.3) - 0.4);
    float3 bladeP = axeP - float3(0.0, 0.35, 0.0);
    float blade1 = sdBox(bladeP - float3(0.1, 0.0, 0.0), float3(0.15, 0.12, 0.03));
    float blade2 = sdBox(bladeP + float3(0.1, 0.0, 0.0), float3(0.15, 0.12, 0.03));
    float axeBlade = min(blade1, blade2);
    float axe = min(handle, axeBlade);
    if(axe < d.x) d = float3(axe, 0.0, 6.0);
    
    float3 legLP = wp - float3(-0.15, -0.55, 0.0);
    float3 legRP = wp - float3(0.15, -0.55, 0.0);
    float legL = length(legLP.xz) - 0.12;
    legL = max(legL, abs(legLP.y) - 0.25);
    float legR = length(legRP.xz) - 0.12;
    legR = max(legR, abs(legRP.y) - 0.25);
    if(legL < d.x) d = float3(legL, 0.0, 7.0);
    if(legR < d.x) d = float3(legR, 0.0, 7.0);
    
    return d;
}

float3 map(float3 p, float time) {
    float3 result = float3(p.y + 1.2, 1e10, 10.0);
    
    float3 wallP = p;
    float walls = -sdBox(wallP, float3(6.0, 5.0, 8.0));
    if(walls < result.x) result = float3(walls, 0.0, 10.0);
    
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float3 pillP = p;
        pillP.xz = mod(pillP.xz + fi * 1.5 + time * 0.1, 5.0) - 2.5;
        
        float pill = length(pillP.xz) - 0.35;
        pill = max(pill, abs(pillP.y + 0.5) - 2.0);
        if(pill < result.x) result = float3(pill, 0.0, 11.0);
        
        for(int j = 0; j < 4; j++) {
            float fj = float(j);
            float3 spikeP = pillP - float3(
                cos(fj * 1.57 + time) * 0.4,
                -1.0 + fj * 0.6,
                sin(fj * 1.57 + time) * 0.4
            );
            float spike = length(spikeP.xyz) - 0.08;
            spike = max(spike, abs(spikeP.y) - 0.15);
            if(spike < result.x) result = float3(spike, 0.0, 11.0);
        }
    }
    
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float3 orcPos = float3(
            -2.5 + fi * 1.8 + sin(time * 0.3 + fi * 1.5) * 0.4,
            -1.2 + abs(sin(time * 2.5 + fi)) * 0.08,
            -3.5 + fi * 0.7
        );
        
        float3 oP = p - orcPos;
        float angle = sin(time * 0.15 + fi * 0.8) * 0.4;
        float2 rotP = float2(
            oP.x * cos(angle) - oP.z * sin(angle),
            oP.x * sin(angle) + oP.z * cos(angle)
        );
        oP.x = rotP.x;
        oP.z = rotP.y;
        
        float3 orc = orcSDF(oP, time, fi);
        if(orc.x < result.x) result = float3(orc.x, orc.y, 20.0 + fi);
    }
    
    float3 gateP = p - float3(0.0, -0.5, 4.0);
    float gate = sdBox(gateP, float3(2.0, 1.5, 0.3));
    float barPattern = step(0.5, fract(gateP.x * 4.0));
    gate = max(gate, -(barPattern * 0.1));
    if(gate < result.x) result = float3(gate, 0.0, 12.0);
    
    float3 bannerP = p - float3(-3.5, 2.5, 3.0);
    float banner = sdBox(bannerP, float3(0.15, 0.8, 0.02));
    banner = max(banner, -bannerP.y + 2.0 + sin(time * 2.0 + bannerP.y * 3.0) * 0.1);
    if(banner < result.x) result = float3(banner, 0.0, 13.0);
    
    float3 banner2P = p - float3(3.5, 2.5, 3.0);
    float banner2 = sdBox(banner2P, float3(0.15, 0.8, 0.02));
    banner2 = max(banner2, -banner2P.y + 2.0 + sin(time * 2.3 + banner2P.y * 3.0) * 0.1);
    if(banner2 < result.x) result = float3(banner2, 0.0, 13.0);
    
    float3 torchP1 = p - float3(-2.0, 1.0, 2.5);
    float torch1 = sdCylinder(torchP1.xzy, float2(0.05, 0.3));
    if(torch1 < result.x) result = float3(torch1, 0.0, 14.0);
    
    float3 torchP2 = p - float3(2.0, 1.0, 2.5);
    float torch2 = sdCylinder(torchP2.xzy, float2(0.05, 0.3));
    if(torch2 < result.x) result = float3(torch2, 0.0, 14.0);
    
    return result;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float3 ro = float3(3.5 * sin(t * 0.25), 1.8 + sin(t * 0.18) * 0.25, -5.5);
    float3 rd = normalize(float3(uv, 1.0));
    rd = lookAt(ro, float3(0, -0.5, 0)) * rd;
    
    float dTotal = 0.0;
    float3 hitMaterial = float3(0.0);
    float3 accumulatedGlow = float3(0.0);
    float3 accumulatedEmissive = float3(0.0);
    
    for(int i = 0; i < 64; i++) {
        float3 p = ro + rd * dTotal;
        float3 mapResult = map(p, t);
        float d = mapResult.x;
        hitMaterial = mapResult;
        
        float lavaDist = p.y + 1.2;
        accumulatedGlow += float3(1.0, 0.2, 0.0) * 0.025 / (1.0 + lavaDist * lavaDist * 1.5);
        
        float3 torchPos1 = float3(-2.0, 1.3, 2.5);
        float3 torchPos2 = float3(2.0, 1.3, 2.5);
        float torchGlow1 = 0.15 + 0.1 * sin(t * 8.0 + p.x * 2.0);
        float torchGlow2 = 0.15 + 0.1 * sin(t * 7.5 + p.y * 2.0);
        accumulatedEmissive += float3(1.0, 0.5, 0.1) * torchGlow1 / (1.0 + length(p - torchPos1) * 2.0);
        accumulatedEmissive += float3(1.0, 0.4, 0.1) * torchGlow2 / (1.0 + length(p - torchPos2) * 2.0);
        
        if(d < 0.001 || dTotal > 28.0) break;
        dTotal += d * 0.65;
    }
    
    float3 color = float3(0.03, 0.005, 0.0);
    float flicker = 0.75 + 0.25 * sin(t * 18.0) * sin(t * 23.0) * sin(t * 31.0);
    
    if(dTotal < 28.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t).x - map(p - float3(0.01,0,0), t).x,
            map(p + float3(0,0.01,0), t).x - map(p - float3(0,0.01,0), t).x,
            map(p + float3(0,0,0.01), t).x - map(p - float3(0,0,0.01), t).x
        ));
        
        float3 lp1 = float3(0, -1.5, 0);
        float3 lp2 = float3(3.0, -1.2, -2.0);
        float3 lp3 = float3(-3.0, -1.0, 1.0);
        float3 lp4 = float3(-2.0, 1.3, 2.5);
        float3 lp5 = float3(2.0, 1.3, 2.5);
        
        float diff1 = max(dot(n, normalize(p - lp1)), 0.0);
        float diff2 = max(dot(n, normalize(p - lp2)), 0.0) * 0.6;
        float diff3 = max(dot(n, normalize(p - lp3)), 0.0) * 0.6;
        float diff4 = max(dot(n, normalize(p - lp4)), 0.0) * 1.2;
        float diff5 = max(dot(n, normalize(p - lp5)), 0.0) * 1.2;
        
        float atten1 = 1.0 / (1.0 + length(p - lp1) * 0.25);
        float atten2 = 1.0 / (1.0 + length(p - lp2) * 0.4);
        float atten3 = 1.0 / (1.0 + length(p - lp3) * 0.4);
        float atten4 = 1.0 / (1.0 + length(p - lp4) * 1.5);
        float atten5 = 1.0 / (1.0 + length(p - lp5) * 1.5);
        
        float3 baseColor = float3(0.12, 0.06, 0.04);
        float3 emissive = float3(0.0);
        float ambientOcclusion = 1.0;
        
        int matId = int(hitMaterial.z);
        
        if(matId >= 20 && matId <= 23) {
            int orcIdx = matId - 20;
            float3 orcPos = float3(
                -2.5 + float(orcIdx) * 1.8,
                -1.2,
                -3.5 + float(orcIdx) * 0.7
            );
            float skinVariation = 0.15 + 0.1 * sin(float(orcIdx) * 2.5);
            baseColor = float3(0.18 + skinVariation * 0.15, 0.45 + skinVariation * 0.2, 0.12);
            
            if(p.z > orcPos.z + 0.16 && abs(p.x - orcPos.x) > 0.05 && p.y < orcPos.y + 0.28) {
                baseColor = float3(0.92, 0.88, 0.78);
            }
            
            if(abs(p.x - orcPos.x) > 0.28 && p.y > orcPos.y - 0.05) {
                baseColor = float3(0.12, 0.1, 0.08);
            }
            
            if(p.x > orcPos.x + 0.28 && p.y > orcPos.y - 0.25) {
                baseColor = float3(0.55, 0.5, 0.45);
                float blood = snoise(p * 12.0 + t);
                if(blood > 0.5) baseColor = float3(0.5, 0.08, 0.02);
            }
            
            ambientOcclusion = 0.7;
        }
        else if(matId == 10) {
            baseColor = float3(0.18, 0.12, 0.08);
            float brickPattern = step(0.5, fract(p.y * 2.0)) * step(0.5, fract(p.x * 3.0));
            baseColor = mix(baseColor, baseColor * 0.7, brickPattern * 0.3);
        }
        else if(matId == 11) {
            baseColor = float3(0.15, 0.1, 0.08);
        }
        else if(matId == 12) {
            baseColor = float3(0.08, 0.06, 0.05);
        }
        else if(matId == 13) {
            baseColor = float3(0.5, 0.15, 0.1);
            float wave = sin(p.y * 10.0 + t * 3.0) * 0.5 + 0.5;
            baseColor = mix(baseColor, float3(0.7, 0.2, 0.1), wave * 0.3);
        }
        else if(matId == 14) {
            baseColor = float3(0.15, 0.08, 0.05);
            emissive = float3(1.0, 0.5, 0.1) * (0.8 + 0.4 * sin(t * 10.0 + p.y * 5.0));
        }
        
        if(p.y < -1.05) {
            baseColor = float3(1.0, 0.15 + flicker * 0.25, 0.0);
            float lavaNoise = snoise(p.xz * 4.0 + t * 0.5);
            float lavaNoise2 = snoise(p.xz * 8.0 - t * 0.3);
            baseColor += float3(0.3, 0.15, 0.0) * lavaNoise;
            baseColor += float3(0.1, 0.05, 0.0) * lavaNoise2;
            emissive = float3(1.0, 0.3, 0.0) * (0.6 + flicker * 0.4);
        }
        
        float paintPattern = snoise(p * 5.0 + t * 0.08);
        if(paintPattern > 0.65 && p.y > -0.3) {
            baseColor = mix(baseColor, float3(0.65, 0.08, 0.02), 0.5);
        }
        
        float runePattern = snoise(p * 8.0);
        if(runePattern > 0.75 && p.y > 0.5 && p.y < 3.0) {
            baseColor = mix(baseColor, float3(0.8, 0.2, 0.1), 0.6);
            emissive += float3(0.2, 0.05, 0.02);
        }
        
        float3 lavaLight = float3(1.0, 0.25, 0.0) * flicker;
        float3 torchLight = float3(1.0, 0.55, 0.15);
        
        color = baseColor * 0.08 * ambientOcclusion;
        color += baseColor * diff1 * lavaLight * atten1 * 9.0;
        color += baseColor * diff2 * lavaLight * atten2 * 5.0;
        color += baseColor * diff3 * lavaLight * atten3 * 5.0;
        color += baseColor * diff4 * torchLight * atten4 * 2.0;
        color += baseColor * diff5 * torchLight * atten5 * 2.0;
        color += emissive;
    }
    
    color += accumulatedGlow * flicker;
    color += accumulatedEmissive * flicker;
    
    for(int i = 0; i < 10; i++) {
        float fi = float(i);
        float2 ashUV = uv + float2(
            sin(t * 0.25 + fi * 1.5) * 0.8,
            t * 0.12 + fi * 0.1
        );
        float ash = smoothstep(0.025, 0.0, length(ashUV));
        float ashAlpha = 0.2 + 0.1 * sin(t * 2.5 + fi * 2.0);
        color += float3(0.4, 0.3, 0.25) * ash * ashAlpha;
    }
    
    float3 fogColor = float3(0.18, 0.06, 0.02);
    color = mix(color, fogColor, 1.0 - exp(-dTotal * 0.08));
    
    // Simplified background glow instead of stars loop
    float3 starsGlow = float3(0.0);
    float starField = smoothstep(0.1, 0.0, length(fract(uv * 5.0) - 0.5));
    starsGlow = float3(0.7, 0.55, 0.35) * starField * 0.15;
    color += starsGlow * (1.0 - smoothstep(0.0, 0.25, rd.y));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}