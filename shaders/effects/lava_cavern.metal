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
    float3 color = float3(0.02, 0.01, 0.02);

    float wall = smoothstep(0.0, 0.3, abs(p.x) - 0.6) + smoothstep(0.0, 0.2, p.y - 0.7);
    color = mix(color, float3(0.08, 0.05, 0.04), wall);

    float lavaY = -0.5 + sin(p.x * 2.0 + t * 0.3) * 0.05;
    float lava = smoothstep(0.05, 0.0, p.y - lavaY);
    float3 lavaCol = mix(float3(0.9, 0.2, 0.0), float3(1.0, 0.7, 0.1), 0.5 + 0.5 * sin(p.x * 4.0 + t));
    lavaCol *= 1.0 + uniforms.bass * 0.5 * uniforms.intensity;
    color = mix(color, lavaCol, lava);

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float cx = sin(fi * 2.3) * 0.5;
        float cy = 0.2 + fi * 0.2;
        float d = length(p - float2(cx, cy));
        float crack = smoothstep(0.15, 0.05, d) * (0.5 + 0.5 * sin(t * 1.5 + fi));
        color += float3(1.0, 0.4, 0.0) * crack * 0.6;
    }

    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float2 em = float2(sin(fi * 3.1 + t * 0.2) * 0.7, fmod(t * (0.1 + fi * 0.02) + fi * 0.5, 1.2) - 0.6);
        float e = smoothstep(0.015, 0.0, length(p - em));
        color += float3(1.0, 0.5, 0.1) * e * 0.7;
    }

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return float4(color, uniforms.alpha);
}