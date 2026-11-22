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
float3 color = float3(0.02, 0.0, 0.08);
for (int i = 0; i < 15; i++) {
    float fi = float(i);
    float2 sp = float2(hash(fi * 3.1) * 2.0 - 1.0, hash(fi * 7.7) * 2.0 - 1.0) * 0.85;
    float d = length(p - sp);
    float core = exp(-d * 12.0);
    float rays = pow(max(0.0, 1.0 - abs(sin(atan2(p.y - sp.y, p.x - sp.x) * 4.0 + t))), 8.0) * 0.3;
    float3 neon = mix(float3(1.0, 0.2, 0.8), float3(0.2, 0.8, 1.0), fi / 15.0);
    color += neon * (core + rays) * (0.6 + uniforms.treble * 0.5 * uniforms.intensity);
}
color *= 1.0 - smoothstep(0.9, 1.7, length(p));
return float4(color, 1.0);

}
