#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

inline float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
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
    float3 color = mix(float3(0.0, 0.15, 0.35), float3(0.0, 0.05, 0.15), uv.y);

    float caustic = 0.0;
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        caustic += sin(p.x * (8.0 + fi * 3.0) + t * 0.6 + fi) *
                   sin(p.y * (7.0 + fi * 2.0) - t * 0.5);
    }
    caustic = 0.5 + 0.5 * caustic / 2.0;
    color += float3(0.4, 0.7, 0.9) * caustic * 0.25 * (0.6 + uniforms.mid * 0.4);

    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float cx = -0.8 + fi * 0.4;
        float sway = sin(t * 0.8 + fi) * 0.05;
        float2 cPos = float2(cx + sway, -0.7 + fi * 0.05);
        float h = 0.25 + fi * 0.08;
        float2 q = p - cPos;
        float d = sdSegment(q, float2(0.0, 0.0), float2(sway, h));
        float col = fillSDF(d, 0.015);
        float3 coralCol = mix(float3(0.9, 0.3, 0.4), float3(1.0, 0.6, 0.2), fi / 5.0);
        color += coralCol * col * 0.9;
        float tip = smoothstep(0.02, 0.0, length(q - float2(sway, h)));
        color += float3(1.0, 0.9, 0.7) * tip * 0.4;
    }

    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float fx = fmod(t * (0.15 + fi * 0.05) + fi * 0.7, 2.4) - 1.2;
        float fy = -0.2 + sin(t * 0.5 + fi) * 0.3;
        float2 fPos = float2(fx, fy);
        float2 q = p - fPos;
        float body = length(q * float2(1.0, 2.0)) - 0.06;
        float fish = fillSDF(body, 0.01);
        color = mix(color, float3(0.05, 0.05, 0.08), fish * 0.8);
    }

    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float bx = -0.9 + fi * 0.25;
        float by = fmod(t * (0.2 + uniforms.mid * 0.3) + fi * 0.4, 2.0) - 1.0;
        float bubble = smoothstep(0.025, 0.02, length(p - float2(bx, by)));
        color += float3(0.7, 0.9, 1.0) * bubble * 0.5;
    }

    color *= 1.0 - smoothstep(0.7, 1.5, length(p));

    return float4(color, uniforms.alpha);
}