//
//  SMPTE calibration shader
//  Renders SMPTE color bars for HDR calibration
//

#include <metal_stdlib>
using namespace metal;

struct CalibrationVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex CalibrationVertexOut calibration_vertex(
    uint vertexID [[vertex_id]]
) {
    const float2 positions[4] = {
        float2(-1, -1), float2(1, -1),
        float2(-1,  1), float2(1,  1)
    };
    const float2 texCoords[4] = {
        float2(0, 1), float2(1, 1),
        float2(0, 0), float2(1, 0)
    };
    
    CalibrationVertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragment_main(
    CalibrationVertexOut in [[stage_in]],
    constant float &peakBrightness [[buffer(0)]]
) {
    float x = in.texCoord.x;
    float y = in.texCoord.y;
    
    float3 color = float3(0);
    
    // 75% SMPTE color bars (8 vertical bars)
    // Each bar is 1/8 of width
    if (x < 0.125) {
        // White - 75%
        color = float3(0.75);
    } else if (x < 0.25) {
        // Yellow
        color = float3(0.75, 0.75, 0);
    } else if (x < 0.375) {
        // Cyan
        color = float3(0, 0.75, 0.75);
    } else if (x < 0.5) {
        // Green
        color = float3(0, 0.75, 0);
    } else if (x < 0.625) {
        // Magenta
        color = float3(0.75, 0, 0.75);
    } else if (x < 0.75) {
        // Red
        color = float3(0.75, 0, 0);
    } else if (x < 0.875) {
        // Blue
        color = float3(0, 0, 0.75);
    } else {
        // Black - 75%
        color = float3(0.075);
    }
    
    // Bottom 5% - black gradient
    if (y < 0.05) {
        color *= 0.1 * y / 0.05;
    }
    
    // Apply peak brightness (nits)
    color *= peakBrightness / 1000.0;
    
    return float4(color, 1.0);
}