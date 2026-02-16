#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Mandelbrot set with smooth coloring
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.05;
    
    // Zoom and pan (animated zoom out)
    float zoom = 0.5 + sin(t * 0.1) * 0.3;
    float2 center = float2(-0.5, 0.0);
    
    float2 c = p * zoom + center;
    float2 z = float2(0.0);
    
    // Mandelbrot iteration
    int maxIter = 100;
    float iter = 0.0;
    
    for (int i = 0; i < 100; i++) {
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
    
    // Color mapping
    float3 color = float3(0.0);
    
    if (iter < float(maxIter)) {
        // Outside - smooth gradient
        float t2 = iter / float(maxIter);
        t2 = pow(t2, 0.5); // Gamma correction
        
        color = hsv2rgb(float3(t2 * 0.8 + t * 0.1, 0.8, 1.0 - t2 * 0.5));
    } else {
        // Inside - dark
        color = float3(0.0);
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
