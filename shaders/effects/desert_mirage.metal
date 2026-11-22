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
    float3 color = mix(float3(0.5, 0.7, 1.0), float3(0.9, 0.6, 0.3), smoothstep(-0.1, 0.4, p.y));

    float sun = smoothstep(0.12, 0.08, length(p - float2(0.6, 0.5)));
    color += float3(1.0, 0.9, 0.6) * sun;

    float dune = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float h = -0.2 - fi * 0.15 + sin(p.x * (2.0 + fi) + t * 0.1) * 0.05;
        dune = max(dune, smoothstep(h + 0.02, h, p.y));
    }
    float3 sandCol = mix(float3(0.85, 0.65, 0.35), float3(0.7, 0.5, 0.25), uv.y * 0.5 + 0.5);
    color = mix(color, sandCol, dune);

    if (p.y < 0.1) {
        float haze = sin(p.x * 20.0 + t * 2.0) * 0.02 * (0.3 - p.y);
        float mirage = smoothstep(0.0, 0.3, -p.y) * 0.4;
        color = mix(color, float3(0.6, 0.7, 0.9), mirage * (0.5 + 0.5 * sin(t + p.x * 5.0)));
    }

    float shimmer = sin(p.x * 30.0 + t * 3.0) * 0.5 + 0.5;
    color += float3(0.9, 0.8, 0.6) * shimmer * smoothstep(0.1, -0.3, p.y) * 0.05;

    color *= 1.0 + uniforms.bass * 0.1 * uniforms.intensity;

    return float4(color, uniforms.alpha);
}