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
float x = 0.1, y = 0.0, z = 0.0;
for (int i = 0; i < 200; i++) {
    float dx = 10.0 * (y - x);
    float dy = x * (28.0 - z) - y;
    float dz = x * y - (8.0 / 3.0) * z;
    x += dx * 0.005; y += dy * 0.005; z += dz * 0.005;
    float2 proj = float2(x, z) * 0.025;
    float d = length(p - proj);
    color += float3(0.2, 0.8, 1.0) * exp(-d * 40.0) * 0.02;
}
color *= 1.0 + uniforms.bass * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
