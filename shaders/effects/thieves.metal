// Thieves 3D - Dark Alley & Treasure
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float map(float3 p, float time) {
    // Walls of the alley
    float walls = -sdBox(p, float3(2.0, 4.0, 10.0));
    
    // Treasure chest
    float3 cp = p - float3(0.0, -0.6, 0.0);
    float chest = sdBox(cp, float3(0.5, 0.3, 0.4));
    
    // Some gold coins scattered
    float coins = 1e10;
    for(int i=0; i<5; i++) {
        float3 sp = p - float3(sin(float(i))*1.2, -0.9, cos(float(i))*1.2);
        coins = min(coins, length(sp) - 0.1);
    }
    
    return min(walls, min(chest, coins));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float3 ro = float3(0.0, 0.0, -4.0);
    float3 rd = normalize(float3(uv, 1.0));
    
    // Thief vision: slightly green/dark
    float dTotal = 0.0;
    for(int i=0; i<64; i++) {
        float d = map(ro + rd*dTotal, t);
        if(d < 0.001 || dTotal > 20.0) break;
        dTotal += d;
    }
    
    float3 color = float3(0.02, 0.02, 0.05);
    
    if(dTotal < 20.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        // Single dim lantern light
        float3 lp = float3(1.5, 2.0, -2.0);
        float diff = max(dot(n, normalize(lp-p)), 0.0);
        float atten = 1.0 / (1.0 + length(lp-p));
        
        if(length(p.xz) < 0.6 && p.y < -0.2) {
            // Chest
            color = float3(0.4, 0.2, 0.1) * diff * atten * 4.0;
        } else if (p.y < -0.85) {
            // Coins
            color = float3(1.0, 0.8, 0.0) * (diff + 0.5) * atten * 6.0;
        } else {
            // Bricks / Walls
            float bricks = sin(p.x * 10.0) * sin(p.y * 10.0);
            color = float3(0.1, 0.1, 0.1) * (0.8 + 0.2 * bricks) * diff * atten * 2.0;
        }
    }
    
    // Vignette
    color *= smoothstep(1.5, 0.5, length(uv));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}