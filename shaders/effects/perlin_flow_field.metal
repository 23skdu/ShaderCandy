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
float3 color = float3(0.0, 0.02, 0.08);
for (int i = 0; i < 60; i++) {
    float fi = float(i);
    float2 pos = p;
    for (int j = 0; j < 8; j++) {
        float fj = float(j);
        pos += float2(sin(pos.y * 3.0 + t * 0.2 + fj), cos(pos.x * 3.0 - t * 0.15 + fj)) * 0.05;
    }
    float d = length(pos - p);
    color += float3(0.3, 0.6, 1.0) * exp(-d * 200.0) * 0.05;
}
color *= 1.0 - smoothstep(0.9, 1.6, length(p));
return float4(color, 1.0);

}
