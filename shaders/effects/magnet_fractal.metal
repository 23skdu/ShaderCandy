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
float2 p = centered * 1.4;
float2 z = p;
float n = 0.0;
for (int i = 0; i < 32; i++) {
    float r2 = dot(z, z);
    if (r2 > 100.0) { n = float(i); break; }
    float x = z.x, y = z.y;
    float denom = (3.0 * x * x + (y - 1.0) * (y - 1.0));
    denom = max(denom, 1e-6);
    float2 nz = float2((x * (x * x - 3.0 * y * (y - 2.0))) / denom,
                    (y * (3.0 * x * x - (y - 1.0) * (y - 1.0) + 1.0)) / denom);
    z = nz + p * 0.1;
}
float v = n / 32.0;
float3 color = 0.5 + 0.5 * cos(6.2831 * (v + float3(0.0, 0.33, 0.67)));
color *= smoothstep(0.0, 0.2, v);
return float4(color, 1.0);

}
