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
    float3 color = mix(float3(0.7, 0.8, 0.95), float3(0.9, 0.95, 1.0), uv.y);

    float crack = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float c = sin(p.x * (5.0 + fi * 3.0) + p.y * (3.0 + fi * 2.0) + fi * 2.0);
        crack = max(crack, smoothstep(0.92, 0.98, abs(c)));
    }
    color = mix(color, float3(0.4, 0.55, 0.75), crack * 0.6);

    float snow = smoothstep(0.1, 0.0, p.y + 0.4 + sin(p.x * 4.0) * 0.05);
    color = mix(color, float3(1.0), snow * 0.7);

    float aurora = 0.5 + 0.5 * sin(p.x * 3.0 + t * 0.4);
    float refl = smoothstep(0.0, -0.6, p.y) * aurora * 0.3;
    color += float3(0.2, 0.6, 0.4) * refl * (0.5 + uniforms.treble * 0.5 * uniforms.intensity);

    float spark = smoothstep(0.02, 0.0, length(p - float2(sin(t * 0.2) * 0.4, -0.1)));
    color += float3(1.0) * spark * 0.5;

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return float4(color, uniforms.alpha);
}