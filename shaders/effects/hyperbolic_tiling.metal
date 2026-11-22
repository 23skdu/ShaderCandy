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
float r = length(p);
float ang = atan2(p.y, p.x);
float rings = sin(log(r + 0.1) * 6.0 + t) * 0.5 + 0.5;
float spokes = sin(ang * 7.0 + t * 0.5) * 0.5 + 0.5;
float pat = rings * spokes;
float3 color = mix(float3(0.05, 0.0, 0.15), float3(0.9, 0.3, 0.6), pat);
color *= exp(-r * 1.2);
color *= 1.0 + uniforms.mid * 0.3 * uniforms.intensity;
return float4(color, 1.0);

}
