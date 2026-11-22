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
    float3 color = mix(float3(0.0, 0.0, 0.05), float3(0.02, 0.0, 0.12), uv.y);

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 sUV = p * (40.0 + fi * 30.0);
        float n = hash(floor(sUV) + fi * 17.0);
        if (n > 0.985) {
            float tw = 0.5 + 0.5 * sin(t * (1.0 + fi) + n * 20.0);
            color += float3(0.8, 0.9, 1.0) * tw * 0.6;
        }
    }

    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float x = p.x + sin(t * 0.3 + fi) * 0.2;
        float wave = sin(x * (3.0 + fi) + t * (0.4 + fi * 0.15) + fi * 1.7);
        float band = exp(-pow((p.y - (0.1 + fi * 0.15 + wave * 0.1)), 2.0) * 8.0);
        float3 auroraCol = mix(float3(0.1, 0.9, 0.4), float3(0.3, 0.4, 1.0), fi / 4.0);
        auroraCol *= 0.6 + uniforms.bass * 0.4 * uniforms.intensity;
        color += auroraCol * band * (0.5 + 0.5 * sin(t + fi));
    }

    color *= 1.0 - smoothstep(0.9, 1.6, length(p));

    return float4(color, uniforms.alpha);
}