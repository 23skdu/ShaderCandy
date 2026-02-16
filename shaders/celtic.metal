#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Celtic knots pattern
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Dark background
    float3 color = float3(0.02, 0.05, 0.03);
    
    // Grid for knots
    float2 gridSize = 0.25;
    float2 grid = fract(p / gridSize);
    float2 cellID = floor(p / gridSize);
    
    // Celtic knot pattern
    float knot = 0.0;
    
    // Interlocking circles pattern
    float2 center1 = float2(0.25, 0.25);
    float2 center2 = float2(0.75, 0.25);
    float2 center3 = float2(0.25, 0.75);
    float2 center4 = float2(0.75, 0.75);
    
    float r1 = length(grid - center1);
    float r2 = length(grid - center2);
    float r3 = length(grid - center3);
    float r4 = length(grid - center4);
    
    // Ring pattern
    float ring1 = smoothstep(0.18, 0.15, r1) - smoothstep(0.15, 0.12, r1);
    float ring2 = smoothstep(0.18, 0.15, r2) - smoothstep(0.15, 0.12, r2);
    float ring3 = smoothstep(0.18, 0.15, r3) - smoothstep(0.15, 0.12, r3);
    float ring4 = smoothstep(0.18, 0.15, r4) - smoothstep(0.15, 0.12, r4);
    
    knot = ring1 + ring2 + ring3 + ring4;
    
    // Weave effect (alternating over/under)
    float weave = sin(cellID.x + cellID.y) * 0.5 + 0.5;
    
    // Color - emerald green and gold
    float3 knotColor = mix(
        float3(0.1, 0.6, 0.3),  // Green
        float3(0.8, 0.7, 0.3),  // Gold
        weave
    );
    
    color += knotColor * knot;
    
    // Add some glow
    float glow = smoothstep(0.2, 0.0, min(min(r1, r2), min(r3, r4)));
    color += float3(0.2, 0.4, 0.2) * glow * 0.2;
    
    // Border
    float border = smoothstep(0.49, 0.48, max(abs(grid.x - 0.5), abs(grid.y - 0.5)));
    color += float3(0.6, 0.5, 0.2) * border * 0.5;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
