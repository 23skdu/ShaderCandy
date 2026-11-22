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
float2 p = centered * 1.5;
float2 z = p;
int root = 0;
for (int i = 0; i < 32; i++) {
    // z^3 - 1
    float2 z2 = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
    float2 z3 = float2(z2.x * z.x - z2.y * z.y, z2.x * z.y + z2.y * z.x);
    float2 f = z3 - float2(1.0, 0.0);
    float2 df = 3.0 * z2;
    z = z - float2((f.x * df.x + f.y * df.y) / (df.x * df.x + df.y * df.y),
                  (f.y * df.x - f.x * df.y) / (df.x * df.x + df.y * df.y));
    if (length(f) < 1e-4) break;
}
if (distance(z, float2(1.0, 0.0)) < 0.5) root = 0;
else if (distance(z, float2(-0.5, 0.866)) < 0.5) root = 1;
else root = 2;
float3 cols[3];
cols[0] = float3(1.0, 0.3, 0.3);
cols[1] = float3(0.3, 1.0, 0.4);
cols[2] = float3(0.3, 0.4, 1.0);
float3 color = cols[root] * (0.6 + 0.4 * sin(t + float(root)));
color *= 1.0 - smoothstep(0.0, 0.02, length(z - p));
return float4(color, 1.0);

}
