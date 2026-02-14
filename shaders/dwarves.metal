// Dwarves 3D - Underground Forge
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float map(float3 p, float time) {
    // Cave walls (infinitely repeating box cutout)
    float3 caveP = p;
    float cave = -sdBox(caveP, float3(2.0, 2.0, 10.0));
    
    // Pillars
    float3 pillP = p;
    pillP.xz = mod(pillP.xz, 4.0) - 2.0;
    float pill = sdBox(pillP, float3(0.5, 2.0, 0.5));
    
    // Anvil
    float3 anvilP = p - float3(0, -0.2, 0);
    float anvil = sdBox(anvilP, float3(0.3, 0.2, 0.1));
    
    return min(pill, min(cave, anvil));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float2 mouse = uniforms.mouse / uniforms.resolution.xy * 2.0 - 1.0;
    float3 ro = float3(mouse.x * 2.0, 0.5, -3.0 + mouse.y * 2.0);
    float3 rd = normalize(float3(uv, 1.2));
    
    float t = 0.0;
    for(int i=0; i<64; i++) {
        float d = map(ro + rd*t, uniforms.time);
        if(d < 0.001 || t > 20.0) break;
        t += d;
    }
    
    float3 color = float3(0.05, 0.02, 0.01); // Dark cave
    
    if(t < 20.0) {
        float3 p = ro + rd * t;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), uniforms.time) - map(p - float3(0.01,0,0), uniforms.time),
            map(p + float3(0,0.01,0), uniforms.time) - map(p - float3(0,0.01,0), uniforms.time),
            map(p + float3(0,0,0.01), uniforms.time) - map(p - float3(0,0,0.01), uniforms.time)
        ));
        
        // Forge light (flickering orange)
        float3 lp = float3(0, -0.5, -1);
        float flicker = 0.8 + 0.2 * sin(uniforms.time * 20.0);
        float3 lightCol = float3(1.0, 0.4, 0.1) * flicker;
        float diff = max(dot(n, normalize(lp-p)), 0.0);
        float atten = 1.0 / (1.0 + length(lp-p));
        
        color = float3(0.2, 0.15, 0.1) * diff * lightCol * atten * 5.0;
        
        // Add glowing embers/lava in cracks
        if (p.y < -0.4) {
            float embers = stepped_noise(float3(p.xz * 10.0, uniforms.time));
            color += float3(1.0, 0.2, 0.0) * embers * flicker;
        }
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}