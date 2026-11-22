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
float2 p = centered * 1.3;
float3 color = float3(0.0);
for (int s = 0; s < 8; s++) {
    float fs = float(s);
    float2 c = float2(hash(fs * 1.3 + t * 0.01) * 4.0 - 2.0, hash(fs * 7.9) * 4.0 - 2.0);
    float2 z = c;
    for (int i = 0; i < 60; i++) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (dot(z, z) > 4.0) break;
        float2 proj = z * 0.3;
        float d = length(p - proj);
        color += float3(0.4, 0.7, 1.0) * exp(-d * 25.0) * 0.02;
    }
}
color *= 1.0 + uniforms.bass * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
