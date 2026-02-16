#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  cosmic_kaleido.metal
//  ShaderCandy
//
//  3D kaleidoscopic spherical projection with infinite geometric reflections
//

using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Polar coordinates
    float r = length(uv);
    float a = atan2(uv.y, uv.x);
    
    // Kaleidoscope split
    float sides = 8.0;
    float tau = 6.283185;
    a = mod(a, tau / sides) - tau / (sides * 2.0);
    a = abs(a);
    
    float2 kuv = float2(cos(a), sin(a)) * r;
    
    float3 color = float3(0.0);
    for (float i = 0.0; i < 4.0; i++) {
        kuv = abs(kuv) - 0.5 * (1.0 + 0.2 * sin(t * 0.5 + i));
        kuv = rot(t * 0.1 + i) * kuv;
        
        float d = length(kuv);
        float3 c = hsv2rgb(float3(fract(d + t * 0.1 + i * 0.2), 0.7, 1.0));
        color += c * (0.01 / (abs(d - 0.2) + 0.02));
    }
    
    color *= smoothstep(1.0, 0.8, r); // Vignette
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
