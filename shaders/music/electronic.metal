// Electronic 3D - Cyber Motherboard
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float map(float3 p, float time, constant Uniforms &u) {
    float d = p.y + 0.5; // Board base
    
    // Grid of chips
    float3 gp = p;
    float2 id = floor(gp.xz);
    gp.xz = mod(gp.xz, 1.0) - 0.5;
    
    float h = hash(id);
    float chipH = 0.1 + 0.3 * h + 0.2 * u.mid;
    float chip = sdBox(gp - float3(0, chipH*0.5 - 0.5, 0), float3(0.4, chipH, 0.4));
    
    d = min(d, chip);
    
    // Central "CPU"
    float cpu = sdBox(p - float3(0, 0, 0), float3(0.8, 0.2 + u.bass*0.2, 0.8));
    d = min(d, cpu);
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float3 ro = float3(sin(t*0.2)*4.0, 2.0, cos(t*0.2)*4.0);
    float3 rd = normalize(float3(uv, 1.2));
    rd = lookAt(ro, float3(0,0,0)) * rd;
    
    float dTotal = 0.0;
    for(int i=0; i<64; i++) {
        float d = map(ro + rd*dTotal, t, uniforms);
        if(d < 0.001 || dTotal > 20.0) break;
        dTotal += d;
    }
    
    float3 color = float3(0.01, 0.02, 0.05); // Deep blue space
    
    if(dTotal < 20.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t, uniforms) - map(p - float3(0.01,0,0), t, uniforms),
            map(p + float3(0,0.01,0), t, uniforms) - map(p - float3(0,0.01,0), t, uniforms),
            map(p + float3(0,0,0.01), t, uniforms) - map(p - float3(0,0,0.01), t, uniforms)
        ));
        
        float3 lp = float3(2, 5, -2);
        float diff = max(dot(n, normalize(lp-p)), 0.0);
        
        // Cyber-grid coloring
        color = float3(0.1, 0.4, 0.8) * diff;
        
        // Data pulses
        float pulse = sin(p.x * 2.0 + p.z * 2.0 - t * 4.0) * 0.5 + 0.5;
        color += float3(0.0, 1.0, 1.0) * pulse * uniforms.treble;
        
        // Central CPU glow
        if (length(p.xz) < 0.9) {
            color += float3(1.0, 0.2, 0.1) * uniforms.bass * 2.0;
        }
    }
    
    // Digital scanlines
    color *= 0.9 + 0.1 * sin(uv.y * 500.0);
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
