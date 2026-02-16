#include "ShaderInterop.h"

// Sierpinski Gasket in 3D - Classic fractal with tetrahedral symmetry

using namespace metal;

float sierpinski(float3 p, int iterations) {
    float scale = 1.0;
    
    for(int i = 0; i < iterations; i++) {
        // Fold space
        p = abs(p);
        
        // Rotate 90 degrees around Y
        float x = p.x;
        p.x = p.z;
        p.z = x;
        
        // Fold
        p = p * 2.0 - float3(1.0, 1.0, 1.0);
        
        // Scale
        p *= 2.0;
        scale *= 2.0;
        
        // Check which tetrahedron
        if(p.x < p.y) {
            float t = p.x;
            p.x = p.y;
            p.y = t;
        }
        if(p.x < p.z) {
            float t = p.x;
            p.x = p.z;
            p.z = t;
        }
        if(p.y < p.z) {
            float t = p.y;
            p.y = p.z;
            p.z = t;
        }
    }
    
    return length(p) / scale - 0.001;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 3.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.2;
    
    // Camera
    float3 ro = float3(2.0 * sin(t), 1.5, 2.0 * cos(t));
    float3 rd = normalize(float3(p, -1.5));
    
    // Rotate camera
    float c = cos(t * 0.1), s = sin(t * 0.1);
    rd.xz = float2(rd.x * c - rd.z * s, rd.x * s + rd.z * c);
    
    float3 col = float3(0.0);
    float dist = 0.0;
    
    for(int i = 0; i < 64; i++) {
        float3 p3 = ro + rd * dist;
        float d = sierpinski(p3, 7);
        
        if(d < 0.001) {
            // Hit the fractal
            float glow = 1.0 - dist * 0.1;
            col += float3(
                0.5 + 0.5 * sin(p3.x * 5.0 + t),
                0.5 + 0.5 * sin(p3.y * 5.0 + t + 2.0),
                0.5 + 0.5 * sin(p3.z * 5.0 + t + 4.0)
            ) * glow * 0.3;
            break;
        }
        
        dist += d * 0.8;
        if(dist > 5.0) break;
    }
    
    // Add glow
    col += float3(0.1, 0.2, 0.4) * (1.0 - dist * 0.2);
    
    col = pow(col, float3(0.8));
    
    return float4(col * u.intensity, 1.0);
}
