#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  neural_nexus.metal
//  ShaderCandy
//
//  Futuristic neural network and data stream
//

using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float3 color = float3(0.01, 0.0, 0.05); // Deep base
    
    // Grid/Nexus
    float2 gv = fract(uv * 5.0) - 0.5;
    float2 id = floor(uv * 5.0);
    
    for(int y=-1; y<=1; y++) {
        for(int x=-1; x<=1; x++) {
            float2 offs = float2(x, y);
            float2 nid = id + offs;
            float2 p = hash2(nid);
            p = 0.5 * sin(t + p * 6.28);
            
            // Connection lines
            float2 diff = (offs + p) - gv;
            float d = length(diff);
            float line = smoothstep(0.02, 0.01, d);
            
            // Pulsing nodes
            float node = smoothstep(0.08, 0.03, d);
            color += float3(0.0, 0.5, 1.0) * node * (0.5 + 0.5 * sin(t + nid.x));
            
            // Distance connections
            if (length(offs + p) < 1.5) {
                float dist = length((offs + p) - gv);
                float lineGlow = exp(-dist * 20.0);
                color += float3(0.0, 0.2, 0.8) * lineGlow;
            }
        }
    }
    
    // Digital "Falling" Bits
    float m = 0.0;
    for(float i=0; i<1.0; i+=0.2) {
        float2 scrollUV = uv * 3.0 + float2(0.0, t * (0.5 + i));
        scrollUV.x += i * 10.0;
        float h = hash(floor(scrollUV.x * 10.0));
        if (h > 0.8) {
            float bit = step(0.9, fract(scrollUV.y * 10.0 + t));
            color += float3(0.0, 1.0, 1.0) * bit * 0.1;
        }
    }
    
    // Scanlines
    color *= 0.9 + 0.1 * sin(uv.y * 400.0);
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
