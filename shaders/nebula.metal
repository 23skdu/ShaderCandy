#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Nebula - colorful space gas clouds
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Deep space background
    float3 color = float3(0.01, 0.01, 0.02);
    
    // Multiple nebula layers
    float3 nebula = float3(0.0);
    
    // Layer 1 - purple/pink
    float n1 = fbm(float3(p * 2.0, t * 0.2), 5);
    n1 = smoothstep(0.0, 0.8, n1);
    float3 nebula1 = float3(0.6, 0.2, 0.8) * n1;
    
    // Layer 2 - blue/cyan
    float n2 = fbm(float3(p * 3.0 + 5.0, t * 0.15 + 3.0), 5);
    n2 = smoothstep(0.1, 0.7, n2);
    float3 nebula2 = float3(0.2, 0.5, 0.9) * n2;
    
    // Layer 3 - orange/red
    float n3 = fbm(float3(p * 1.5 + 10.0, t * 0.25 + 7.0), 5);
    n3 = smoothstep(0.2, 0.75, n3);
    float3 nebula3 = float3(0.9, 0.4, 0.2) * n3;
    
    nebula = nebula1 + nebula2 + nebula3;
    
    // Stars
    float stars = pow(noise(p * 300.0), 25.0);
    float stars2 = pow(noise(p * 150.0 + 50.0), 20.0) * 0.7;
    
    // Twinkling
    float twinkle = sin(t * 5.0 + p.x * 100.0) * 0.3 + 0.7;
    stars *= twinkle;
    
    // Combine
    color += nebula * 0.6;
    color += float3(1.0, 0.98, 0.95) * (stars + stars2);
    
    // Add glow
    color += nebula * 0.2;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
