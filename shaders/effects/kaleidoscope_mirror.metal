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
float ang = atan2(p.y, p.x);
float r = length(p);
int segs = 8;
float seg = 6.28318 / float(segs);
ang = fmod(ang, seg);
ang = abs(ang - seg * 0.5);
float2 q = float2(cos(ang), sin(ang)) * r;
float pat = 0.5 + 0.5 * sin(q.x * 10.0 + t) * cos(q.y * 8.0 - t * 0.7);
float3 color = mix(float3(0.1, 0.0, 0.2), float3(0.9, 0.4, 1.0), pat);
color *= exp(-r * 0.8);
color *= 1.0 + uniforms.treble * 0.3 * uniforms.intensity;
return float4(color, 1.0);

}
