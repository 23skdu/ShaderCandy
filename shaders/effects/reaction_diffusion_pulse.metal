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
float a = 0.5 + 0.5 * sin(p.x * 8.0 + t) * cos(p.y * 6.0 - t * 0.7);
float b = 0.5 + 0.5 * cos(p.x * 5.0 - t * 0.5) * sin(p.y * 9.0 + t * 0.9);
float pat = a * b;
float3 color = mix(float3(0.1, 0.0, 0.2), float3(0.9, 0.4, 0.1), pat);
color += float3(0.2, 0.8, 1.0) * smoothstep(0.7, 0.9, pat) * 0.5 * (1.0 + uniforms.mid * uniforms.intensity);
color *= 1.0 - smoothstep(0.9, 1.5, length(p));
return float4(color, 1.0);

}
