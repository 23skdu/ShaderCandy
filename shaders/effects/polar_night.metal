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
    float3 color = mix(float3(0.0, 0.02, 0.08), float3(0.05, 0.05, 0.15), uv.y);

    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float2 sUV = p * (30.0 + fi * 25.0);
        float n = hash(floor(sUV) + fi * 13.0);
        if (n > 0.98) {
            float tw = 0.5 + 0.5 * sin(t * (0.8 + fi * 0.3) + n * 15.0);
            color += float3(0.9, 0.95, 1.0) * tw * 0.7;
        }
    }

    float2 moonPos = float2(-0.5, 0.5);
    float moonDist = length(p - moonPos);
    float moon = smoothstep(0.12, 0.10, moonDist);
    color += float3(0.9, 0.9, 0.8) * moon;
    color += float3(0.4, 0.45, 0.6) * exp(-moonDist * 3.0) * 0.3;

    float horizon = -0.6 + sin(p.x * 3.0) * 0.05;
    float snow = smoothstep(horizon + 0.05, horizon, p.y);
    color = mix(color, float3(0.85, 0.9, 0.95), snow * 0.8);

    float aurora = 0.5 + 0.5 * sin(p.x * 2.0 + t * 0.2);
    color += float3(0.1, 0.4, 0.3) * aurora * smoothstep(0.6, 0.2, p.y) * 0.2 * (0.5 + uniforms.volume * 0.5 * uniforms.intensity);

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return float4(color, uniforms.alpha);
}