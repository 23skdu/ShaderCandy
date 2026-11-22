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

    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float phase = p.x * (4.0 + fi) + p.y * (3.0 - fi) + t * (0.5 + fi * 0.2);
        float band = 0.5 + 0.5 * sin(phase);
        band = pow(band, 2.0);
        float3 hue = float3(
            0.5 + 0.5 * sin(fi * 1.0 + t * 0.3),
            0.5 + 0.5 * sin(fi * 2.0 + t * 0.4 + 2.0),
            0.5 + 0.5 * sin(fi * 3.0 + t * 0.5 + 4.0)
        );
        color += hue * band * 0.15 * (0.6 + uniforms.bass * 0.4 * uniforms.intensity);
    }

    float r = length(p);
    float prism = smoothstep(0.3, 0.0, r) * (0.5 + 0.5 * sin(t * 2.0));
    color += float3(0.9, 0.9, 1.0) * prism * 0.4;

    color *= 1.0 - smoothstep(0.8, 1.6, r);

    return float4(color, uniforms.alpha);
}