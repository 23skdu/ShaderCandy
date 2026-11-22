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
float u = 0.5 + 0.5 * sin(p.x * 12.0 + t * 0.3) * cos(p.y * 10.0 - t * 0.2);
float v = 0.5 + 0.5 * cos(p.x * 8.0 - t * 0.4) * sin(p.y * 14.0 + t * 0.35);
float pat = smoothstep(0.4, 0.6, u - v);
float3 color = mix(float3(0.05, 0.1, 0.2), float3(0.9, 0.7, 0.3), pat);
color *= 1.0 + uniforms.bass * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
