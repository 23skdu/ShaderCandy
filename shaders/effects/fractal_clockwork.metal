#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

inline float fillSDF(float d, float blur) {
    return 1.0 - smoothstep(-blur, blur, d);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;

    float t = fmod(uniforms.time * uniforms.speed, 3600.0);

    float2 p = centered;
    float3 color = float3(0.08, 0.06, 0.04);

    float gearSpeed = 0.5 + uniforms.volume * 0.5 * uniforms.intensity;

    color = mix(float3(0.12, 0.09, 0.05), float3(0.25, 0.18, 0.1), uv.y);

    float r = length(p);
    float angle = atan2(p.y, p.x);
    float gear1 = abs(sin(angle * 12.0 + t * gearSpeed)) * 0.05;
    float d1 = r - (0.5 + gear1);
    float gearFill1 = fillSDF(d1, 0.01);
    float teeth1 = step(0.48, r) * step(r, 0.55) * step(0.5, abs(sin(angle * 12.0 + t * gearSpeed)));
    color += float3(0.8, 0.6, 0.2) * gearFill1 * 0.7;
    color += float3(0.9, 0.75, 0.3) * teeth1 * 0.5;

    float hub = fillSDF(r - 0.12, 0.01);
    color = mix(color, float3(0.3, 0.2, 0.1), hub);

    float2 g2Pos = float2(0.7, 0.2);
    float2 q2 = p - g2Pos;
    float r2 = length(q2);
    float a2 = atan2(q2.y, q2.x);
    float gear2Fill = fillSDF(r2 - 0.22, 0.01);
    float teeth2 = step(0.18, r2) * step(r2, 0.26) * step(0.5, abs(sin(a2 * 8.0 - t * gearSpeed * 1.5)));
    color += float3(0.7, 0.5, 0.15) * gear2Fill * 0.6;
    color += float3(0.85, 0.7, 0.3) * teeth2 * 0.4;

    float2 ep = p * 1.5;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        ep = abs(ep) - float2(0.3 - fi * 0.05);
        ep = rot(t * gearSpeed * 0.2 + fi) * ep;
        float d = length(ep) - 0.05;
        float f = fillSDF(d, 0.005);
        color += float3(0.95, 0.85, 0.5) * f * (0.3 / (fi + 1.0));
    }

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return float4(color, uniforms.alpha);
}