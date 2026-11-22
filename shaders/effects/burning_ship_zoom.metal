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
float2 p = centered * 1.2;
float zoom = 1.0 + 0.5 * sin(t * 0.2);
p /= zoom;
float2 c = p + float2(-0.5, -0.5);
float2 z = float2(0.0);
float n = 0.0;
for (int i = 0; i < 48; i++) {
    z = float2(abs(z.x), abs(z.y));
    z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    if (dot(z, z) > 4.0) { n = float(i); break; }
}
float v = n / 48.0;
float3 color = 0.5 + 0.5 * cos(6.2831 * (v * 4.0 + float3(0.0, 0.1, 0.2)));
color *= smoothstep(0.0, 0.15, v);
return float4(color, 1.0);

}
