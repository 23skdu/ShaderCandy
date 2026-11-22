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
float R = 0.6, r = 0.25, d = 0.4;
float u = t * 0.5;
float x = (R - r) * cos(u) + d * cos((R - r) / r * u);
float y = (R - r) * sin(u) - d * sin((R - r) / r * u);
float2 pt = float2(x, y);
float trail = 0.0;
for (int i = 0; i < 200; i++) {
    float fi = float(i);
    float uu = fi * 0.05 + t * 0.5;
    float xx = (R - r) * cos(uu) + d * cos((R - r) / r * uu);
    float yy = (R - r) * sin(uu) - d * sin((R - r) / r * uu);
    float dd = length(p - float2(xx, yy));
    trail += exp(-dd * 30.0) * 0.02;
}
float3 color = float3(0.02, 0.0, 0.08) + float3(0.3, 0.8, 1.0) * trail;
color += float3(1.0, 0.4, 0.7) * exp(-length(p - pt) * 20.0) * 0.5;
color *= 1.0 + uniforms.volume * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
