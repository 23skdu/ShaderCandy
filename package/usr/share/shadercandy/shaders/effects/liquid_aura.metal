#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  liquid_aura.metal
//  ShaderCandy
//
//  Molten iridescent mirror surface with fluid ripples
//

using namespace ShaderUtils;

float heightMap(float2 p, float t) {
    float h = 0.0;
    float amp = 0.5;
    float freq = 0.8;
    for (int i = 0; i < 4; i++) {
        h += amp * snoise(p * freq + t * 0.4);
        amp *= 0.5;
        freq *= 2.1;
    }
    return h;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float3 ro = float3(0, 1.0, -3.0);
    float3 rd = normalize(float3(uv, 1.5));
    rd = rotX(-0.5) * rd;
    
    // Plane intersection (y = 0)
    float td = -ro.y / rd.y;
    float3 color = float3(0.0);
    
    if (td > 0.0) {
        float3 p = ro + rd * td;
        float2 eps = float2(0.01, 0.0);
        float h = heightMap(p.xz, t);
        float3 n = normalize(float3(
            heightMap(p.xz - eps.xy, t) - heightMap(p.xz + eps.xy, t),
            0.5,
            heightMap(p.xz - eps.yx, t) - heightMap(p.xz + eps.yx, t)
        ));
        
        float3 ref = reflect(rd, n);
        float3 sky = hsv2rgb(float3(fract(ref.y * 2.0 + t * 0.1), 0.6, 0.9));
        float fre = pow(1.0 + dot(rd, n), 5.0);
        
        color = mix(sky * 0.5, hsv2rgb(float3(fract(h + t * 0.2), 0.8, 1.0)), fre);
        color *= exp(-td * 0.1);
    } else {
        color = hsv2rgb(float3(fract(rd.y + t * 0.05), 0.5, 0.2));
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
