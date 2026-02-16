#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    float2 p = float2(atan2(uv.y, uv.x) / 3.14159, 0.5 / length(uv)) + t * 0.1;
    p.y += p.x * 2.0;
    
    // Grid pattern
    float2 grid = fract(p * 5.0) - 0.5;
    float d = length(max(abs(grid) - 0.2, 0.0));
    
    float3 col = float3(0.0);
    
    // Kaleidoscopic colors
    float3 c1 = float3(0.5 + 0.5 * sin(t), 0.5 + 0.5 * cos(t * 0.5), 0.5);
    float3 c2 = float3(0.5 + 0.5 * sin(t * 1.5 + 2.0), 0.5 + 0.5 * cos(t + 4.0), 1.0);
    
    float mask = smoothstep(0.1, 0.0, d);
    col = mix(c1, c2, mask * sin(uv.x * 10.0 + t));
    
    // Add glow
    col += float3(0.1, 0.2, 1.0) / length(uv) * 0.2;
    
    col *= uniforms.intensity;
    return float4(col, uniforms.alpha);
}
