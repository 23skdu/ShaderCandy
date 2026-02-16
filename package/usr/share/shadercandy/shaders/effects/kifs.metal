#include "ShaderInterop.h"

// KIFS (Kaleidoscopic IFS) Fractal - Iterated function system with symmetry

using namespace metal;

float kifs(float3 p, float t) {
    float scale = 2.0;
    int iterations = 6;
    
    // Rotation angles that animate
    float a1 = t * 0.3;
    float a2 = t * 0.2;
    float a3 = t * 0.1;
    
    float3 offset = float3(1.0, 1.0, 1.0);
    float3 ro = p;
    
    for(int i = 0; i < iterations; i++) {
        // Fold
        p = abs(p);
        
        // Rotate around X
        float c = cos(a1), s = sin(a1);
        float3 p1 = float3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
        
        // Rotate around Y
        c = cos(a2); s = sin(a2);
        float3 p2 = float3(p1.x * c + p1.z * s, p1.y, -p1.x * s + p1.z * c);
        
        // Rotate around Z
        c = cos(a3); s = sin(a3);
        p = float3(p2.x * c - p2.y * s, p2.x * s + p2.y * c, p2.z);
        
        // Scale and translate
        p = p * scale - offset;
    }
    
    return (length(p) - 2.0) * pow(scale, -float(iterations));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 3.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.15;
    
    // Camera
    float3 ro = float3(2.0 * sin(t * 0.5), 2.0 * cos(t * 0.3), -3.0);
    float3 rd = normalize(float3(p, 1.5));
    
    float3 col = float3(0.0);
    float dist = 0.0;
    
    for(int i = 0; i < 64; i++) {
        float3 p3 = ro + rd * dist;
        float d = kifs(p3, t);
        
        if(abs(d) < 0.001) {
            // Hit - add color
            float glow = 1.0;
            col += float3(
                0.5 + 0.5 * sin(p3.x * 3.0 + t * 2.0),
                0.5 + 0.5 * sin(p3.y * 3.0 + t * 2.0 + 2.0),
                0.5 + 0.5 * sin(p3.z * 3.0 + t * 2.0 + 4.0)
            ) * glow * 0.2;
            break;
        }
        
        dist += d * 0.7;
        if(dist > 6.0) break;
    }
    
    // Add background glow
    col += float3(0.1, 0.05, 0.2) * (1.0 - dist * 0.15);
    
    col = pow(col, float3(0.8));
    
    return float4(col * u.intensity, 1.0);
}
