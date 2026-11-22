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
for (int i = 0; i < 120; i++) {
    float fi = float(i);
    float u = fi * 0.08 + t * 0.4;
    float x = sin(3.0 * u + 1.0) * 0.5;
    float y = sin(4.0 * u) * 0.5;
    float z = sin(5.0 * u + 2.0) * 0.3;
    float2 proj = float2(x, y + z * 0.4);
    float d = length(p - proj);
    color += float3(0.9, 0.6, 0.2) * exp(-d * 40.0) * 0.05;
}
color *= 1.0 - smoothstep(0.9, 1.6, length(p));
return float4(color, 1.0);

}
