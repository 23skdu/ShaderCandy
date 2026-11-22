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
float3 color = float3(0.02, 0.02, 0.08);
float2 pt = float2(0.0);
float u = t * 0.5;
for (int k = 1; k <= 6; k++) {
    float fk = float(k);
    float amp = 1.0 / fk;
    float phase = fk * u;
    pt += float2(cos(phase), sin(phase)) * amp * 0.4;
}
// draw trail
for (int i = 0; i < 150; i++) {
    float fi = float(i);
    float uu = fi * 0.04 + t * 0.5;
    float2 ppt = float2(0.0);
    for (int k = 1; k <= 6; k++) {
        float fk = float(k);
        ppt += float2(cos(fk * uu), sin(fk * uu)) * (1.0 / fk) * 0.4;
    }
    float d = length(p - ppt);
    color += float3(0.4, 0.9, 0.7) * exp(-d * 50.0) * 0.02;
}
color += float3(1.0, 0.3, 0.6) * exp(-length(p - pt) * 20.0) * 0.6;
color *= 1.0 + uniforms.bass * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
