#include "ShaderInterop.h"

// 3D IFS (Iterated Function System) - Procedural plant/fern-like fractal

using namespace metal;

float3x3 rotateX(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(
        1.0, 0.0, 0.0,
        0.0, c, -s,
        0.0, s, c
    );
}

float3x3 rotateY(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
}

float ifs(float3 p, float t) {
    float scale = 2.0;
    int iterations = 10;
    
    float3 offset = float3(0.5, 0.5, 0.5);
    
    for(int i = 0; i < iterations; i++) {
        // Scale
        p /= scale;
        
        // Apply transforms based on position
        if(p.x < 0.0) {
            p = -p + offset;
        }
        if(p.y < 0.0) {
            p = rotateX(1.5708) * (-p + offset);
        }
        if(p.z < 0.0) {
            p = rotateY(1.5708) * (-p + offset);
        }
        
        // Rotate
        p = rotateY(t * 0.1) * p;
        
        // Fold
        p = abs(p - offset) + offset * 0.5;
    }
    
    return length(p);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 3.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.2;
    
    // Camera
    float3 ro = float3(2.0 * sin(t * 0.3), 1.5, 2.0 * cos(t * 0.3));
    float3 rd = normalize(float3(p, 1.5));
    
    float3 col = float3(0.0);
    float dist = 0.0;
    
    for(int i = 0; i < 48; i++) {
        float3 p3 = ro + rd * dist;
        
        // Simple distance estimate
        float d = ifs(p3, t) * 0.01;
        
        if(d < 0.001) {
            float glow = exp(-d * 20.0);
            col += float3(
                0.3 + 0.7 * sin(p3.y * 5.0 + t),
                0.3 + 0.7 * sin(p3.y * 5.0 + t + 1.0),
                0.3 + 0.7 * sin(p3.y * 5.0 + t + 2.0)
            ) * glow * 0.3;
            break;
        }
        
        dist += d * 0.8;
        if(dist > 5.0) break;
    }
    
    // Background
    col += float3(0.05, 0.02, 0.1) * (1.0 - dist * 0.2);
    
    col = pow(col, float3(0.8));
    
    return float4(col * u.intensity, 1.0);
}
