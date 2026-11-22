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
float3 color = float3(0.0, 0.0, 0.05);
for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float y = sin(p.x * (2.5 + fi) + t * (1.0 + fi * 0.4)) * 0.12 * (1.0 + fi * 0.3);
    float beam = smoothstep(0.015, 0.0, abs(p.y - y));
    float3 hue = float3(0.5 + 0.5 * sin(fi + t), 0.5 + 0.5 * sin(fi * 2.0 + t * 1.3), 0.5 + 0.5 * sin(fi * 3.0 + t * 1.7));
    color += hue * beam * (0.7 + uniforms.bass * 0.5 * uniforms.intensity);
}
for (int i = 0; i < 20; i++) {
    float fi = float(i);
    float2 sp = float2(hash(fi * 1.7) * 2.0 - 1.0, hash(fi * 9.3) * 2.0 - 1.0) * 0.9;
    float star = smoothstep(0.012, 0.0, length(p - sp)) * (0.5 + 0.5 * sin(t * 2.0 + fi));
    color += float3(0.8, 0.9, 1.0) * star * 0.5;
}
color *= 1.0 - smoothstep(0.9, 1.6, length(p));
return float4(color, 1.0);

}
