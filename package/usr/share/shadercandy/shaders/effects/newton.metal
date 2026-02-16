#include "ShaderInterop.h"

// Newton Fractal - Root-finding iteration visualization

using namespace metal;

float2 newton(float2 z, int iter) {
    // Complex derivative
    float2 dz = float2(1.0, 0.0);
    float2 roots[3] = {
        float2(1.0, 0.0),
        float2(-0.5, 0.866),
        float2(-0.5, -0.866)
    };
    
    for(int i = 0; i < iter; i++) {
        // z^3 - 1 derivative = 3z^2
        float2 z2 = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
        float2 z3 = float2(z.x * z2.x - z.y * z2.y, z.x * z2.y + z.y * z2.x);
        
        float2 f = z3 - float2(1.0, 0.0);
        float2 fprime = 3.0 * z2;
        
        // Newton step: z = z - f/f'
        float denom = dot(fprime, fprime);
        z = z - float2(f.x * fprime.x + f.y * fprime.y, f.y * fprime.x - f.x * fprime.y) / denom;
        
        // Update derivative
        dz = dz * 3.0 * z2;
    }
    
    // Find closest root
    float2 root = roots[0];
    float minD = dot(z - roots[0], z - roots[0]);
    
    for(int i = 1; i < 3; i++) {
        float d = dot(z - roots[i], z - roots[i]);
        if(d < minD) {
            minD = d;
            root = roots[i];
        }
    }
    
    return z - root;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 4.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.15;
    
    // Animate c parameter
    p += float2(0.1 * sin(t), 0.1 * cos(t * 0.7));
    
    float2 d = newton(p, 20);
    float dist = length(d);
    
    float3 col;
    if(dist < 0.001) {
        col = float3(0.0);
    } else {
        // Color based on which root it converged to
        float angle = atan2(d.y, d.x);
        float hue = angle / 6.28318 + 0.5;
        
        col = float3(
            0.5 + 0.5 * cos(hue * 6.28 + 0.0),
            0.5 + 0.5 * cos(hue * 6.28 + 2.094),
            0.5 + 0.5 * cos(hue * 6.28 + 4.188)
        );
        
        // Add glow based on iteration count
        col *= exp(-dist * 2.0);
    }
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.5;
    col *= vig;
    
    return float4(col * u.intensity, 1.0);
}
