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
float2 c = float2(-0.7 + 0.1 * sin(t), 0.27 + 0.1 * cos(t));
float2 z = p;
float trap = 1e9;
for (int i = 0; i < 48; i++) {
    z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    trap = min(trap, length(z));
    if (dot(z, z) > 100.0) break;
}
float v = clamp(trap * 0.5, 0.0, 1.0);
float3 color = mix(float3(0.9, 0.2, 0.4), float3(0.1, 0.4, 0.9), v);
color *= 0.7 + 0.3 * sin(trap * 10.0 + t);
return float4(color, 1.0);

}
