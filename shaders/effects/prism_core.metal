#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  prism_core.metal
//  ShaderCandy
//
//  Exploding geometric prism with volumetric light core
//

using namespace ShaderUtils;

float prismSDF(float3 p, float t) {
    float3 q = abs(p);
    float d1 = max(q.x, max(q.y, q.z)) - 1.0;
    
    // Cutting spheres
    for (int i = 0; i < 4; i++) {
        float3 sp = float3(sin(t + float(i)), cos(t * 1.5 + float(i)), sin(t * 0.7 + float(i))) * 1.2;
        d1 = max(d1, -(length(p - sp) - 0.5));
    }
    
    return d1;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float3 ro = float3(0, 0, -3.0);
    float3 rd = normalize(float3(uv, 1.5));
    rd = rotX(t * 0.2) * rotY(t * 0.3) * rd;
    ro = rotX(t * 0.2) * rotY(t * 0.3) * ro;
    
    float td = 0.0, d;
    float3 color = float3(0.0);
    float glow = 0.0;
    
    for (int i = 0; i < 64; i++) {
        float3 p = ro + rd * td;
        d = prismSDF(p, t);
        if (d < 0.001 || td > 8.0) break;
        td += d;
        glow += 0.02 / (1.0 + d * 10.0);
    }
    
    if (td < 8.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            prismSDF(p + float3(0.01, 0, 0), t) - prismSDF(p - float3(0.01, 0, 0), t),
            prismSDF(p + float3(0, 0.01, 0), t) - prismSDF(p - float3(0, 0.01, 0), t),
            prismSDF(p + float3(0, 0, 0.01), t) - prismSDF(p - float3(0, 0, 0.01), t)
        ));
        color = float3(0.1, 0.3, 0.5) * max(0.0, dot(n, -rd));
        color += pow(1.0 + dot(rd, n), 4.0) * hsv2rgb(float3(fract(t * 0.1), 0.7, 1.0));
    }
    
    color += glow * hsv2rgb(float3(fract(t * 0.2), 0.8, 1.0));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
