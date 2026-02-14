// Elves 3D - Mystical Forest
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float map(float3 p, float time) {
    float d = p.y + 0.5; // ground
    
    // Forest pillars (trees)
    float3 treeP = p;
    float2 grid = floor(treeP.xz / 2.0);
    treeP.xz = mod(treeP.xz, 2.0) - 1.0;
    float h = hash(grid);
    float tree = length(treeP.xz) - (0.1 + h * 0.1);
    d = min(d, tree);
    
    // Floating magic wisps (fairies/elves)
    for(int i=0; i<3; i++) {
        float3 wispP = p - float3(sin(time + float(i)*2.0)*1.5, 1.0 + cos(time*0.5 + float(i))*0.5, cos(time + float(i)*3.0)*1.5);
        d = min(d, sdSphere(wispP, 0.05));
    }
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float2 mouse = uniforms.mouse / uniforms.resolution.xy * 2.0 - 1.0;
    float3 ro = float3(mouse.x * 2.0, 1.0, -3.0 + mouse.y * 2.0);
    float3 rd = normalize(float3(uv, 1.5));
    
    float t = 0.0;
    for(int i=0; i<80; i++) {
        float d = map(ro + rd*t, uniforms.time);
        if(d < 0.001 || t > 20.0) break;
        t += d;
    }
    
    float3 color = float3(0.01, 0.05, 0.02); // Deep forest green
    
    if(t < 20.0) {
        float3 p = ro + rd * t;
        float distToWisp = 1e10;
        for(int i=0; i<3; i++) {
            float3 wispP = p - float3(sin(uniforms.time + float(i)*2.0)*1.5, 1.0 + cos(uniforms.time*0.5 + float(i))*0.5, cos(uniforms.time + float(i)*3.0)*1.5);
            distToWisp = min(distToWisp, length(wispP));
        }
        
        if(distToWisp < 0.1) {
            color = float3(0.5, 1.0, 0.8) * 2.0; // Magic wisp glow
        } else if (p.y < -0.45) {
            // Forest floor
            float3 floorCol = float3(0.1, 0.2, 0.1);
            color = floorCol * (1.0 - t/20.0);
        } else {
            // Trees
            color = float3(0.05, 0.1, 0.02) * (1.0 - t/20.0);
        }
    }
    
    // Atmospheric fog/glow
    color += float3(0.1, 0.2, 0.15) * (1.0 / (1.0 + t*0.1));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}