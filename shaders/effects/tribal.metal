#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Tribal pattern
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Dark earth background
    float3 color = float3(0.1, 0.08, 0.05);
    
    // Tribal patterns using symmetry
    float2 symP = p;
    symP.x = abs(symP.x);
    
    // Triangular elements
    float tri = 0.0;
    
    // Main triangle rows
    for (float i = 0.0; i < 4.0; i++) {
        float yPos = -0.6 + i * 0.4;
        float triWidth = 0.8 - i * 0.15;
        float triHeight = 0.25;
        
        // Triangle shape
        float2 triP = symP - float2(0.0, yPos);
        if (triP.y > 0.0 && triP.y < triHeight) {
            float triX = triP.y / triHeight * triWidth;
            if (triP.x < triX) {
                // Inner detail
                float innerX = triP.y / triHeight * (triWidth * 0.6);
                if (triP.x > innerX) {
                    color = float3(0.9, 0.7, 0.4); // Inner color
                } else {
                    color = float3(0.8, 0.5, 0.2); // Main color
                }
            }
        }
    }
    
    // Zigzag pattern
    float zigzag = sin(symP.y * 30.0) * symP.x;
    float zigzagLine = smoothstep(0.02, 0.0, abs(zigzag - 0.2));
    color = mix(color, float3(0.9, 0.6, 0.3), zigzagLine * 0.5);
    
    // Dots
    for (float i = 0.0; i < 8.0; i++) {
        float dotY = -0.7 + i * 0.2;
        float dotX = 0.1 + (mod(i, 2.0) - 0.5) * 0.15;
        
        float dot = smoothstep(0.03, 0.0, length(symP - float2(dotX, dotY)));
        color = mix(color, float3(0.95, 0.8, 0.5), dot);
    }
    
    // Border elements
    float border = smoothstep(0.9, 0.85, max(abs(p.x), abs(p.y)));
    color = mix(color, float3(0.7, 0.5, 0.3), border);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
