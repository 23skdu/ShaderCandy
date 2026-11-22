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
float a = 1.4, b = 0.3;
float x = 0.1, y = 0.1;
for (int i = 0; i < 300; i++) {
    float cc = 0.5 + 0.5 * sin(t * 0.1);
    float dd = 1.6 + 0.2 * cos(t * 0.07);
    float nx = sin(a * y) + cc * cos(a * x);
    float ny = sin(b * x) + dd * cos(b * y);
    x = nx; y = ny;
    float2 proj = float2(x, y) * 0.35;
    float d2 = length(p - proj);
    color += float3(1.0, 0.4, 0.7) * exp(-d2 * 30.0) * 0.015;
}
return float4(color, 1.0);

}
