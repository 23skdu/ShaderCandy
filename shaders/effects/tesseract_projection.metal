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
for (int i = 0; i < 16; i++) {
    float fi = float(i);
    float a = fi * 0.3927 + t * 0.2;
    float r = 0.6;
    float2 v = float2(cos(a), sin(a)) * r;
    v += float2(sin(t * 0.5 + fi) * 0.1, cos(t * 0.4 + fi) * 0.1);
    float d = length(p - v);
    color += float3(0.6, 0.8, 1.0) * exp(-d * 30.0) * 0.15;
}
// connecting lines approximation
float grid = smoothstep(0.01, 0.0, abs(sin(p.x * 8.0 + t)) * abs(sin(p.y * 8.0 - t)));
color += float3(0.3, 0.5, 0.9) * grid * 0.2;
color *= 1.0 + uniforms.bass * 0.2 * uniforms.intensity;
return float4(color, 1.0);

}
