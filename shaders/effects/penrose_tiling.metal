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
float2 p = centered * 2.0;
float scale = 0.5;
float3 color = float3(0.05, 0.05, 0.1);
for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float a = fi * 1.2566 + t * 0.1;
    float2 g = float2(cos(a), sin(a)) * scale;
    float band = smoothstep(0.05, 0.0, abs(dot(p, float2(-sin(a), cos(a))) - (scale * 0.5)));
    color += mix(float3(0.9, 0.6, 0.2), float3(0.2, 0.5, 0.9), fi / 5.0) * band * 0.25;
    scale *= 0.618;
}
color *= 1.0 - smoothstep(1.0, 2.0, length(p));
return float4(color, 1.0);

}
