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
float u = p.x * 3.0 + t * 0.4;
float v = p.y * 3.0;
float x = (1.0 + v * 0.3 * cos(u * 0.5)) * cos(u);
float y = (1.0 + v * 0.3 * cos(u * 0.5)) * sin(u);
float z = v * 0.3 * sin(u * 0.5);
float2 proj = float2(x, y + z * 0.4) * 0.35;
float d = length(p - proj);
float band = smoothstep(0.15, 0.0, d);
float3 color = mix(float3(0.05, 0.0, 0.15), float3(0.9, 0.4, 0.8), band);
color += float3(0.3, 0.8, 1.0) * exp(-d * 20.0) * 0.4;
return float4(color, 1.0);

}
