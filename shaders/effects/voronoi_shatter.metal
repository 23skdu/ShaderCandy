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
float minD = 1e9;
float2 minP = float2(0.0);
for (int i = 0; i < 12; i++) {
    float fi = float(i);
    float2 cell = float2(hash(fi * 1.3) * 2.0 - 1.0, hash(fi * 7.9) * 2.0 - 1.0) * 0.8;
    cell += float2(sin(t * 0.3 + fi), cos(t * 0.25 + fi)) * 0.1;
    float d = length(p - cell);
    if (d < minD) { minD = d; minP = cell; }
}
float edge = smoothstep(0.0, 0.02, minD - 0.05);
float3 color = mix(float3(0.8, 0.3, 0.1), float3(0.1, 0.2, 0.5), hash(minP.x + minP.y * 10.0));
color *= edge;
color += float3(1.0, 0.9, 0.7) * (1.0 - smoothstep(0.0, 0.03, minD)) * 0.6;
color *= 1.0 + uniforms.bass * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
