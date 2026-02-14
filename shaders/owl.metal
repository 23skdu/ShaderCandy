// Owl 3D - Night Watch
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float map(float3 p, float time) {
    // Tree branch
    float branch = length(p.xy - float2(0.0, -0.2)) - 0.2;
    
    // Owl Head
    float3 op = p - float3(0.0, 0.4, 0.0);
    float head = sdSphere(op, 0.4);
    // Ears (tufts)
    float tuftL = sdSphere(op - float3(-0.25, 0.35, 0.0), 0.1);
    float tuftR = sdSphere(op - float3(0.25, 0.35, 0.0), 0.1);
    
    // Beak
    float beak = sdSphere(op - float3(0.0, -0.1, 0.35), 0.1);
    
    float d = min(branch, head);
    d = min(d, min(tuftL, tuftR));
    d = min(d, beak);
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float3 ro = float3(0.5 * sin(t*0.5), 0.5, -2.5);
    float3 rd = normalize(float3(uv, 1.2));
    
    float dTotal = 0.0;
    for(int i=0; i<64; i++) {
        float d = map(ro + rd*dTotal, t);
        if(d < 0.001 || dTotal > 10.0) break;
        dTotal += d;
    }
    
    float3 color = float3(0.01, 0.01, 0.05); // Night sky
    
    if(dTotal < 10.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        float3 lp = float3(1, 2, -2);
        float diff = max(dot(n, normalize(lp-p)), 0.0);
        
        if(p.y < 0.0) {
            // Branch
            color = float3(0.2, 0.1, 0.05) * (diff + 0.1);
        } else {
            // Owl
            float3 owlCol = float3(0.3, 0.25, 0.2); // Brown feathers
            
            // Glowing Eyes
            float2 euv = p.xy - float2(0.0, 0.5);
            float distE1 = length(euv - float2(-0.2, 0.0));
            float distE2 = length(euv - float2(0.2, 0.0));
            
            if(distE1 < 0.12 || distE2 < 0.12) {
                float3 yellowEye = float3(1.0, 0.8, 0.0);
                float pupil = smoothstep(0.04, 0.03, min(distE1, distE2));
                owlCol = mix(yellowEye, float3(0.0), pupil);
                // Add glow
                owlCol *= 1.5 + 0.5 * sin(t*3.0);
            }
            
            color = owlCol * (diff + 0.1);
        }
    }
    
    // Background stars
    color += float3(1.0) * step(0.998, hash(uv * 100.0 + t*0.01)) * 0.5;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}