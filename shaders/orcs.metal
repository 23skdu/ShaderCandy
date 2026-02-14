// Orcs 3D - Volcanic Fortress
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float map(float3 p, float time) {
    float d = p.y + 1.0; // Lava floor
    
    // Fortress walls
    float3 wallP = p;
    float walls = -sdBox(wallP, float3(5.0, 4.0, 5.0));
    
    // Spiky pillars
    float3 pillP = p;
    pillP.xz = mod(pillP.xz, 3.0) - 1.5;
    float pill = length(pillP.xz) - 0.2 * (1.0 - pillP.y * 0.2);
    
    return min(pill, walls);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float3 ro = float3(2.0 * sin(t*0.5), 1.0, -4.0);
    float3 rd = normalize(float3(uv, 1.0));
    rd = lookAt(ro, float3(0,0,0)) * rd;
    
    float dTotal = 0.0;
    for(int i=0; i<64; i++) {
        float d = map(ro + rd*dTotal, t);
        if(d < 0.01 || dTotal > 20.0) break;
        dTotal += d;
    }
    
    float3 color = float3(0.1, 0.02, 0.0); // Dark red sky
    
    if(dTotal < 20.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        float3 lp = float3(0, -0.8, 0); // Lava from below
        float diff = max(dot(n, normalize(p-lp)), 0.0);
        float atten = 1.0 / (1.0 + length(p-lp));
        
        color = float3(0.2, 0.1, 0.05) * (diff + 0.1);
        
        // Lava glow
        float3 lavaCol = float3(1.0, 0.2, 0.0) * (0.8 + 0.2 * sin(t*10.0 + p.x + p.z));
        color += lavaCol * atten * 10.0;
        
        // Add war paint / tribal markings on walls
        float mask = stepped_noise(float3(p.xz * 2.0, p.y + t));
        if(mask > 0.7) color = mix(color, float3(1.0, 0.0, 0.0), 0.5);
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}