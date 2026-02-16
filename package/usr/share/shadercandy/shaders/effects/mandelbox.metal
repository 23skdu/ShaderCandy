#include "ShaderInterop.h"

// Mandelbox Fractal - Box-folded Mandelbrot-like 3D fractal

using namespace metal;

float2 DE(float3 pos) {
    float scale = 2.5;
    float minR = 0.5;
    float fixedR = 1.0;
    int iterations = 8;
    
    float3 z = pos;
    float dr = 1.0;
    float r = 0.0;
    
    for(int i = 0; i < iterations; i++) {
        r = length(z);
        if(r > 4.0) break;
        
        // Box fold
        z = clamp(z, -1.0, 1.0) * 2.0 - z;
        
        // Sphere fold
        float preR = r;
        r = length(z);
        if(r < minR) {
            z = z * (fixedR / minR);
            dr = dr * (fixedR / minR);
        } else if(r < fixedR) {
            z = z * (fixedR / r);
            dr = dr * (fixedR / r);
        }
        
        // Scale and translate
        z = z * scale + float3(0.9, 0.9, 0.9);
        dr = dr * abs(scale) + 1.0;
    }
    
    return float2(0.5 * log(r) * r / dr, r);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 3.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.1;
    
    float3 ro = float3(2.0 * sin(t), 1.5 * cos(t * 0.8), -3.0 * cos(t * 0.3));
    float3 rd = normalize(float3(p, 1.5));
    
    float3 col = float3(0.0);
    float dist = 0.0;
    
    for(int i = 0; i < 80; i++) {
        float3 p3 = ro + rd * dist;
        float2 d = DE(p3);
        
        if(d.x < 0.001) {
            float glow = exp(-d.x * 5.0);
            col += float3(0.3 + 0.7 * glow) * float3(
                0.5 + 0.5 * sin(t + p3.x),
                0.5 + 0.5 * sin(t + p3.y + 2.0),
                0.5 + 0.5 * sin(t + p3.z + 4.0)
            ) * 0.15;
            break;
        }
        
        dist += d.x * 0.7;
        if(dist > 10.0) break;
    }
    
    col = pow(col, float3(0.8));
    
    return float4(col * u.intensity, 1.0);
}
