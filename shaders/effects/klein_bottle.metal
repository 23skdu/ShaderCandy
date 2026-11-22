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
float u = p.x * 3.0 + t * 0.3;
float v = p.y * 3.0;
float x = (2.0 + cos(v * 0.5)) * cos(u);
float y = (2.0 + cos(v * 0.5)) * sin(u);
float z = sin(v * 0.5);
float2 proj = float2(x, y + z * 0.5) * 0.25;
float d = length(p - proj);
float3 color = float3(0.1, 0.2, 0.4) + float3(0.8, 0.5, 0.2) * exp(-d * 8.0);
color *= 1.0 + uniforms.volume * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
