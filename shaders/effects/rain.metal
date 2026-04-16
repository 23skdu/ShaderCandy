#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Rain on window effect
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Window frame color
    float3 color = float3(0.05, 0.08, 0.12);
    
    // Distant lights through rain (blurred)
    float2 lightPos1 = float2(-0.5 + sin(t * 0.3) * 0.2, 0.3);
    float2 lightPos2 = float2(0.3, -0.2 + cos(t * 0.2) * 0.1);
    float2 lightPos3 = float2(0.8, 0.5);
    
    float lights = 0.0;
    lights += exp(-length(p - lightPos1) * 3.0) * 0.8;
    lights += exp(-length(p - lightPos2) * 4.0) * 0.6;
    lights += exp(-length(p - lightPos3) * 5.0) * 0.5;
    
    // Rain drops
    float rain = 0.0;
    for (float i = 0.0; i < 30.0; i++) {
        float seed = i * 0.1 + floor(i * 0.07);
        float2 dropPos = float2(
            hash(seed) * 2.0 - 1.0,
            mod(hash(seed + 100.0) + t * (0.5 + hash(seed) * 0.5), 2.0) - 1.0
        );
        
        // Drop streak
        float dropLen = 0.1 + hash(seed + 200.0) * 0.15;
        float dropWid = 0.008;
        
        // Distance to drop line
        float dx = abs(p.x - dropPos.x);
        float dy = mod(p.y - dropPos.y + dropLen, 2.0) - 1.0;
        
        // Elongated drop
        float drop = smoothstep(dropWid, 0.0, dx) * smoothstep(dropLen, 0.0, dy);
        drop *= smoothstep(-1.0, -0.8, dy);
        
        rain += drop * 0.3;
    }
    
    // Static rain drops (on glass)
    float2 dropUV = uv * float2(20.0, 15.0);
    float2 dropID = floor(dropUV);
    float2 dropF = fract(dropUV) - 0.5;
    
    float staticDrops = 0.0;
    for (float i = -1.0; i <= 1.0; i++) {
        for (float j = -1.0; j <= 1.0; j++) {
            float2 neighbor = float2(i, j);
            float2 id = dropID + neighbor;
            float rnd = hash(id);
            
            if (rnd > 0.85) {
                float2 pos = float2(hash(id + 1.0), hash(id + 2.0)) - 0.5;
                float size = 0.1 + rnd * 0.15;
                float drop = smoothstep(size, 0.0, length(dropF - pos));
                staticDrops += drop * 0.5;
            }
        }
    }
    
    // Refraction effect from drops
    float refraction = staticDrops * 0.3;
    
    // Combine
    color += float3(0.8, 0.85, 1.0) * lights * 0.3;
    color += float3(0.9, 0.95, 1.0) * rain;
    color += float3(0.7, 0.8, 0.9) * staticDrops;
    color += float3(0.5, 0.6, 0.7) * refraction;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
