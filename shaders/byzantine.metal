#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Byzantine mosaic
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.08;
    
    // Dark background
    float3 color = float3(0.1, 0.08, 0.12);
    
    // Hexagonal mosaic pattern
    float2 hexSize = float2(0.1, 0.17);
    float2 hexP = p / hexSize;
    
    // Hexagonal grid offset
    float row = floor(hexP.y);
    if (mod(row, 2.0) > 0.5) {
        hexP.x += 0.5;
    }
    
    float2 hexCell = floor(hexP);
    float2 hexF = fract(hexP) - 0.5;
    
    // Hex distance
    float hexDist = max(abs(hexF.x) * 0.866 + abs(hexF.y) * 0.5, abs(hexF.y));
    
    // Hex tile
    float hexTile = smoothstep(0.5, 0.45, hexDist);
    
    // Color variation per tile
    float tileRand = hash(hexCell.x + hexCell.y * 100.0);
    float3 tileColor;
    
    // Byzantine color palette
    if (tileRand < 0.2) {
        tileColor = float3(0.8, 0.2, 0.2);  // Red
    } else if (tileRand < 0.4) {
        tileColor = float3(0.2, 0.3, 0.8);  // Blue
    } else if (tileRand < 0.5) {
        tileColor = float3(0.9, 0.8, 0.3);  // Gold
    } else if (tileRand < 0.6) {
        tileColor = float3(0.3, 0.6, 0.3);  // Green
    } else if (tileRand < 0.7) {
        tileColor = float3(0.6, 0.4, 0.8);  // Purple
    } else {
        tileColor = float3(0.9, 0.9, 0.9);   // White/marble
    }
    
    color = mix(color, tileColor, hexTile);
    
    // Grout lines
    float grout = smoothstep(0.42, 0.45, hexDist);
    color = mix(color, float3(0.15, 0.12, 0.1), grout);
    
    // Center decoration - cross
    float crossH = smoothstep(0.03, 0.0, abs(p.x)) * step(abs(p.y), 0.15);
    float crossV = smoothstep(0.03, 0.0, abs(p.y)) * step(abs(p.x), 0.08);
    float cross = max(crossH, crossV);
    
    color = mix(color, float3(0.9, 0.8, 0.4), cross);
    
    // Corner decorations
    float2 corners[4] = {float2(-0.7, 0.7), float2(0.7, 0.7), float2(-0.7, -0.7), float2(0.7, -0.7)};
    
    for (int i = 0; i < 4; i++) {
        float cornerDist = length(p - corners[i]);
        float corner = smoothstep(0.15, 0.1, cornerDist);
        color = mix(color, float3(0.8, 0.6, 0.2), corner * 0.6);
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
