#include "ShaderInterop.h"

// Julia 4D Fractal - Four-dimensional Julia set projected to 3D

using namespace metal;

float4 julia4D(float4 z, float4 c) {
    for(int i = 0; i < 12; i++) {
        // Quaternion multiplication
        float x = z.x * z.x - z.y * z.y - z.z * z.z - z.w * z.w;
        float y = 2.0 * z.x * z.y;
        float z2 = 2.0 * z.x * z.z;
        float w = 2.0 * z.x * z.w;
        
        z.x = x + c.x;
        z.y = y + c.y;
        z.z = z2 + c.z;
        z.w = w + c.w;
        
        if(dot(z, z) > 4.0) break;
    }
    return z;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 3.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.15;
    
    // 4D Julia parameter - animates through different shapes
    float4 c = float4(
        0.4 * sin(t * 0.3),
        0.4 * cos(t * 0.2),
        0.4 * sin(t * 0.25),
        0.4 * cos(t * 0.35)
    );
    
    float3 col = float3(0.0);
    
    for(int i = 0; i < 80; i++) {
        // Project 4D to 3D
        float3 ro = float3(p, float(i) * 0.05);
        float4 z = float4(ro, 0.0);
        
        float4 jz = julia4D(z, c);
        float d = length(jz);
        
        if(d < 4.0) {
            float glow = exp(-d * 0.3);
            col += float3(
                0.5 + 0.5 * sin(d * 3.0 + t),
                0.5 + 0.5 * sin(d * 3.0 + t + 2.094),
                0.5 + 0.5 * sin(d * 3.0 + t + 4.188)
            ) * glow * 0.05;
        }
    }
    
    col = pow(col, float3(0.7));
    
    return float4(col * u.intensity, 1.0);
}
