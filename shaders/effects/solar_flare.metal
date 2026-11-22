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
    float r = length(p);

    float3 color = float3(0.0);

    float disk = smoothstep(0.02, 0.0, r - 0.85);

    if (disk > 0.0) {
        float2 q = p * 3.0;
        float n1 = hash(q + float2(t * 0.05, 0.0));
        float n2 = hash(q * 2.0 + float2(0.0, t * 0.03));
        float cells = 0.5 + 0.5 * sin((q.x + n1) * 4.0 + (q.y + n2) * 3.0);

        float spots = hash(floor(p * 8.0));
        spots = step(0.92, spots);

        float3 hot = float3(1.0, 0.9, 0.5);
        float3 cool = float3(0.8, 0.3, 0.05);
        float3 surf = mix(cool, hot, cells);
        surf *= (1.0 - spots * 0.6);

        surf *= 1.0 + uniforms.bass * 0.3 * uniforms.intensity;

        color = surf * disk;
    }

    if (r > 0.80 && r < 1.15) {
        float angle = atan2(p.y, p.x);
        float prom = 0.5 + 0.5 * sin(angle * 6.0 + t * 0.8);
        float limb = smoothstep(0.0, 0.05, r - 0.85) * smoothstep(0.15, 0.0, r - 0.95);
        color += float3(1.0, 0.4, 0.1) * prom * limb * (0.6 + uniforms.bass * 0.4);
    }

    float corona = exp(-r * 2.5) * 0.4;
    color += float3(1.0, 0.7, 0.3) * corona * (0.8 + uniforms.volume * 0.4);

    return float4(color, uniforms.alpha);
}