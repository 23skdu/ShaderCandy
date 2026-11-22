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
    float3 color = float3(0.02, 0.0, 0.05);

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float n = hash(floor(p * (6.0 + fi * 2.0)) + fi);
        float cloud = smoothstep(0.3, 0.7, n) * (0.4 + 0.3 * sin(t * 0.2 + fi));
        float3 nebCol = mix(float3(0.8, 0.2, 0.4), float3(0.2, 0.4, 0.9), fi / 3.0);
        color += nebCol * cloud * 0.3;
    }

    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        float2 sp = float2(hash(fi * 1.3) * 2.0 - 1.0, hash(fi * 7.9) * 2.0 - 1.0) * 0.8;
        float d = length(p - sp);
        float star = exp(-d * 8.0) * (0.6 + 0.4 * sin(t * 1.5 + fi));
        color += float3(1.0, 0.95, 0.8) * star * 0.6;
        float disk = smoothstep(0.12, 0.08, d) * 0.3;
        color += float3(0.9, 0.5, 0.2) * disk * (0.5 + uniforms.volume * 0.5 * uniforms.intensity);
    }

    float dust = smoothstep(0.1, 0.0, abs(sin(p.x * 3.0 + p.y * 2.0 + t * 0.1)));
    color *= 1.0 - dust * 0.3;

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return float4(color, uniforms.alpha);
}