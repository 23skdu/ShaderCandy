#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

inline float sdBox2D(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

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
    float3 color = float3(0.02, 0.03, 0.08);

    float caustic = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        caustic += sin(p.x * (6.0 + fi) + t * (0.4 + fi * 0.2)) *
                   sin(p.y * (5.0 + fi) - t * (0.3 + fi * 0.15));
    }
    caustic = 0.5 + 0.5 * caustic / 3.0;
    color += float3(0.1, 0.2, 0.35) * caustic * 0.4;

    float2 lightPos = uniforms.mouse * 2.0 - 1.0;
    lightPos.x *= uniforms.resolution.x / uniforms.resolution.y;
    float lightDist = length(p - lightPos);
    float light = exp(-lightDist * 1.5) * 0.6;
    color += float3(0.9, 0.95, 1.0) * light;

    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float2 cPos = float2(sin(fi * 1.7 + t * 0.1) * 0.6, -0.3 + fi * 0.15);
        float rotA = fi * 0.8 + t * 0.05;
        float2x2 r = rot(rotA);
        float2 q = r * (p - cPos);
        float d = sdBox2D(q, float2(0.05, 0.18 + fi * 0.03));
        float fill = fillSDF(d, 0.01);
        float3 crystalCol = mix(float3(0.2, 0.5, 0.9), float3(0.8, 0.3, 1.0), fi / 6.0);
        crystalCol *= 1.0 + uniforms.treble * 0.5 * uniforms.intensity;
        float tip = smoothstep(0.02, 0.0, length(q - float2(0.0, 0.18 + fi * 0.03)));
        color += crystalCol * fill + float3(1.0, 0.9, 1.0) * tip * 0.5;
    }

    color *= 1.0 - smoothstep(0.6, 1.4, length(p));

    return float4(color, uniforms.alpha);
}