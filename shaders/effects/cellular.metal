#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Geometric cellular pattern
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.3;
    
    // Voronoi-like cellular pattern
    float2 cellSize = 0.3;
    float2 cellUV = p / cellSize;
    float2 cellID = floor(cellUV);
    float2 cellF = fract(cellUV) - 0.5;
    
    // Random offset per cell
    float2 offset = hash2(cellID) * 0.8 - 0.4;
    offset += float2(sin(t + cellID.x), cos(t + cellID.y)) * 0.1;
    
    float2 cellCenter = offset;
    float dist = length(cellF - cellCenter);
    
    // Edge detection
    float edge = smoothstep(0.1, 0.15, dist) - smoothstep(0.15, 0.2, dist);
    
    // Cell color based on position
    float3 cellColor = hsv2rgb(float3(
        hash(cellID.x + cellID.y * 100.0) + t * 0.1,
        0.7,
        0.8
    ));
    
    // Fill or outline
    float fill = smoothstep(0.2, 0.1, dist);
    float3 color = cellColor * fill;
    
    // Add edges
    color += float3(1.0) * edge * 0.5;
    
    // Background
    color += float3(0.05, 0.05, 0.1) * (1.0 - fill);
    
    // Add some connecting lines between cells
    float2 neighborOffset = float2(1.0, 0.0);
    float2 neighborID = cellID + neighborOffset;
    float2 neighborOffset2 = hash2(neighborID) * 0.8 - 0.4;
    neighborOffset2 += float2(sin(t + neighborID.x), cos(t + neighborID.y)) * 0.1;
    
    // Line between current cell and neighbor
    float2 p1 = cellID * cellSize + cellSize * 0.5 + offset * cellSize;
    float2 p2 = (cellID + neighborOffset) * cellSize + cellSize * 0.5 + neighborOffset2 * cellSize;
    
    float lineDist = length(p - mix(p1, p2, 0.5));
    float line = smoothstep(0.02, 0.0, lineDist);
    color += float3(0.5, 0.5, 0.8) * line * 0.3;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
