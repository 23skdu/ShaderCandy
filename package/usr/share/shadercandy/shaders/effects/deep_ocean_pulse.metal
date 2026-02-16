#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  deep_ocean_pulse.metal
//  ShaderCandy
//
//  Bioluminescent organic blobs in an infinite abyss
//

using namespace ShaderUtils;

float blobSDF(float3 p, float t) {
    float d = 1e10;
    for (int i = 0; i < 5; i++) {
        float3 bp = float3(
            2.0 * sin(t * 0.5 + float(i)),
            2.0 * cos(t * 0.7 + float(i) * 1.5),
            2.0 * sin(t * 0.3 + float(i) * 2.0)
        );
        float sz = 0.5 + 0.3 * sin(t + float(i));
        float dist = length(p - bp) - sz;
        
        // Soft blend
        float k = 0.8;
        float h = clamp(0.5 + 0.5 * (d - dist) / k, 0.0, 1.0);
        d = mix(d, dist, h) - k * h * (1.0 - h);
    }
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float3 ro = float3(0, 0, -5.0);
    float3 rd = normalize(float3(uv, 1.2));
    
    float td = 0.0, d;
    float glow = 0.0;
    for (int i = 0; i < 70; i++) {
        float3 p = ro + rd * td;
        d = blobSDF(p, t);
        if (d < 0.001 || td > 15.0) break;
        td += d;
        glow += 0.015 / (1.0 + d * d * 10.0);
    }
    
    float3 color = float3(0.01, 0.02, 0.05); // Abyss color
    if (td < 15.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            blobSDF(p + float3(0.01, 0, 0), t) - blobSDF(p - float3(0.01, 0, 0), t),
            blobSDF(p + float3(0, 0.01, 0), t) - blobSDF(p - float3(0, 0.01, 0), t),
            blobSDF(p + float3(0, 0, 0.01), t) - blobSDF(p - float3(0, 0, 0.01), t)
        ));
        float fre = pow(1.0 + dot(rd, n), 3.0);
        color = mix(float3(0.0, 0.2, 0.4), hsv2rgb(float3(0.5 + 0.2 * sin(t), 0.8, 1.0)), fre);
        color *= exp(-td * 0.1);
    }
    
    color += glow * hsv2rgb(float3(0.5 + 0.3 * cos(t * 0.2), 0.7, 1.0));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
