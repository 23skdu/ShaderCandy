#include "ShaderInterop.h"

// Mandelbrot 3D Fractal - Three-dimensional Mandelbrot set

using namespace metal;

float3 mandelbrot3D(float3 c) {
    float3 z = c;
    float3 c2 = c * c;
    float dr = 1.0;
    float r = 0.0;
    
    for(int i = 0; i < 8; i++) {
        r = length(z);
        if(r > 4.0) break;
        
        // Derivative for distance estimation
        dr = 2.0 * sqrt(dot(z, z)) * dr + 1.0;
        
        // 3D Mandelbrot iteration
        float x = z.x * z.x - z.y * z.y - z.z * z.z;
        float y = 2.0 * z.x * z.y;
        float z2 = 2.0 * z.x * z.z;
        
        z.x = x + c.x;
        z.y = y + c.y;
        z.z = z2 + c.z;
        
        c2 *= c2;
    }
    
    return float3(0.5 * log(dot(z, z)) * sqrt(dot(z, z)) / dr, r, float(r < 4.0));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 3.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.2;
    
    // Camera setup
    float3 ro = float3(sin(t) * 2.0, cos(t * 0.7) * 1.5, -2.5);
    float3 rd = normalize(float3(p, 1.5));
    
    // Rotate ray direction
    float c = cos(t * 0.1), s = sin(t * 0.1);
    rd.xz = float2(rd.x * c - rd.z * s, rd.x * s + rd.z * c);
    
    float3 col = float3(0.0);
    float dist = 0.0;
    
    for(int i = 0; i < 64; i++) {
        float3 res = mandelbrot3D(ro + rd * dist);
        if(res.y > 4.0) {
            float glow = exp(-res.x * 2.0);
            col += float3(0.5 + 0.5 * sin(res.x * 10.0 + float3(0.0, 2.0, 4.0))) * glow * 0.1;
            break;
        }
        dist += res.x * 0.5;
    }
    
    col = pow(col, float3(0.8));
    
    return float4(col * u.intensity, 1.0);
}
