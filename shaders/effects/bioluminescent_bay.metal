#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;

    float t = fmod(uniforms.time * uniforms.speed, 3600.0);

    float2 p = centered;
    float3 color = mix(float3(0.0, 0.02, 0.08), float3(0.0, 0.05, 0.15), uv.y);

    float shimmer = 0.5 + 0.5 * sin(p.x * 12.0 + t * 0.5) * sin(p.y * 8.0 - t * 0.3);
    color += float3(0.4, 0.5, 0.7) * shimmer * 0.15;

    float2 m = uniforms.mouse * 2.0 - 1.0;
    m.x *= uniforms.resolution.x / uniforms.resolution.y;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float2 trailPos = m + float2(sin(t * 0.4 + fi) * 0.3, cos(t * 0.3 + fi) * 0.2);
        float d = length(p - trailPos);
        float glow = exp(-d * 4.0) * (0.6 + uniforms.mid * 0.4);
        float3 bioCol = mix(float3(0.2, 1.0, 0.6), float3(0.1, 0.8, 1.0), fi / 6.0);
        color += bioCol * glow * (0.7 + uniforms.intensity * 0.3);
    }

    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 sp = float2(hash(fi * 3.7), hash(fi * 9.1)) * 2.0 - 1.0;
        sp.x *= 1.2;
        float tw = 0.5 + 0.5 * sin(t * (1.5 + fi) + fi * 5.0);
        float spark = smoothstep(0.03, 0.0, length(p - sp)) * tw;
        color += float3(0.3, 1.0, 0.7) * spark * 0.4;
    }

    color *= 1.0 - smoothstep(0.8, 1.6, length(p));

    return float4(color, uniforms.alpha);
}