#include <metal_stdlib>
#include "../base/ShaderInterop.h"

using namespace metal;

// SMPTE Color Bars Implementation
// Based on SMPTE RP 219-1:2002

float3 smpte_bars(float2 uv) {
    float3 color = float3(0.0);
    
    // Top 2/3: 75% intensity primary/secondary colors
    if (uv.y > 0.33) {
        int bar = int(uv.x * 7.0);
        switch (bar) {
            case 0: color = float3(0.75, 0.75, 0.75); break; // Grey
            case 1: color = float3(0.75, 0.75, 0.00); break; // Yellow
            case 2: color = float3(0.00, 0.75, 0.75); break; // Cyan
            case 3: color = float3(0.00, 0.75, 0.00); break; // Green
            case 4: color = float3(0.75, 0.00, 0.75); break; // Magenta
            case 5: color = float3(0.75, 0.00, 0.00); break; // Red
            case 6: color = float3(0.00, 0.00, 0.75); break; // Blue
        }
    } 
    // Middle 1/12
    else if (uv.y > 0.25) {
        int bar = int(uv.x * 7.0);
        switch (bar) {
            case 0: color = float3(0.0, 0.0, 0.75); break; // Blue
            case 1: color = float3(0.0, 0.0, 0.0); break;  // Black
            case 2: color = float3(0.75, 0.0, 0.75); break; // Magenta
            case 3: color = float3(0.0, 0.0, 0.0); break;  // Black
            case 4: color = float3(0.0, 0.75, 0.75); break; // Cyan
            case 5: color = float3(0.0, 0.0, 0.0); break;  // Black
            case 6: color = float3(0.75, 0.75, 0.75); break; // Grey
        }
    }
    // Bottom 1/4: PLUGE and primary colors
    else {
        if (uv.x < 1.0/6.0) {
            color = float3(0.0, 0.15, 0.3); // -I
        } else if (uv.x < 2.0/6.0) {
            color = float3(1.0, 1.0, 1.0); // White
        } else if (uv.x < 3.0/6.0) {
            color = float3(0.3, 0.0, 0.5); // +Q
        } else if (uv.x < 4.0/6.0) {
            // PLUGE signal (Super-black, Black, Gray)
            float pluge = uv.x * 6.0 - 3.0; // 0.0 to 1.0 within this segment
            if (pluge < 0.33) color = float3(-0.04); // Super-black
            else if (pluge < 0.66) color = float3(0.0); // Black
            else color = float3(0.04); // Near-black
        } else {
            color = float3(0.1, 0.1, 0.1); // 7.5% Gray
        }
    }
    
    return color;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float3 color = smpte_bars(uv);
    
    // Apply HDR brightness mapping if enabled
    if (uniforms.intensity > 1.0) {
        color *= uniforms.intensity;
    }
    
    return float4(color, 1.0);
}
