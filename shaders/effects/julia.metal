#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Julia set - animated morphing
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.15;
    
    // Animated c parameter
    float cX = 0.7885 * cos(t * 0.3);
    float cY = 0.7885 * sin(t * 0.3);
    float2 c = float2(cX, cY);
    
    float2 z = p * 1.5;
    
    int maxIter = 80;
    float iter = 0.0;
    
    for (int i = 0; i < 80; i++) {
        if (dot(z, z) > 4.0) break;
        
        // z = z^2 + c
        float x = z.x * z.x - z.y * z.y + c.x;
        float y = 2.0 * z.x * z.y + c.y;
        z = float2(x, y);
        
        iter += 1.0;
    }
    
    // Smooth coloring
    if (iter < float(maxIter)) {
        float log_zn = log(dot(z, z)) / 2.0;
        float nu = log(log_zn / log(2.0)) / log(2.0);
        iter = iter + 1.0 - nu;
    }
    
    float3 color = float3(0.0);
    
    if (iter < float(maxIter)) {
        float t2 = iter / float(maxIter);
        t2 = pow(t2, 0.6);
        
        // Electric blue/cyan palette
        color = float3(
            sin(t2 * 6.28 + 0.0) * 0.5 + 0.5,
            sin(t2 * 6.28 + 2.09) * 0.5 + 0.5,
            sin(t2 * 6.28 + 4.18) * 0.5 + 0.5
        );
        color = pow(color, float3(0.8));
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
