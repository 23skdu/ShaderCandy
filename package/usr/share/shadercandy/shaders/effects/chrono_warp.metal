#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  chrono_warp.metal
//  ShaderCandy
//
//  Bending space-time grid with trail effects
//

using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Warp UVs
    float r = length(uv);
    float angle = atan2(uv.y, uv.x);
    angle += 0.5 * sin(r * 3.0 - t);
    float2 wuv = float2(cos(angle), sin(angle)) * r;
    
    float3 color = float3(0.0);
    
    // Grid layers
    for (float i = 0.0; i < 3.0; i++) {
        float scale = 4.0 + i * 2.0;
        float2 gv = fract(wuv * scale + t * 0.2 * (i + 1.0)) - 0.5;
        float dist = length(gv);
        float line = smoothstep(0.48, 0.45, abs(gv.x)) + smoothstep(0.48, 0.45, abs(gv.y));
        
        float3 layerColor = hsv2rgb(float3(fract(t * 0.1 + i * 0.3), 0.7, 1.0));
        color += layerColor * line * exp(-r * 2.0) * (0.5 / (i + 1.0));
    }
    
    // Core pulse
    color += hsv2rgb(float3(fract(t * 0.5), 0.8, 1.0)) * (0.1 / (r + 0.01));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
