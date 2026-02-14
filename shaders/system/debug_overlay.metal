#include <metal_stdlib>
// #include "ShaderInterop.h" (Auto-included)

using namespace metal;

/* struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
}; */

fragment float4 fragment_main(VertexOut in [[stage_in]],
                                       constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    
    // GPU Bar (top)
    float2 gpuPos = float2(0.02, 0.02);
    float2 barSize = float2(0.3, 0.015);
    
    // CPU Bar (below)
    float2 cpuPos = float2(0.02, 0.045);
    
    float4 color = float4(0.0);
    
    // Background for both
    if (uv.x > 0.01 && uv.x < 0.35 && uv.y > 0.01 && uv.y < 0.07) {
        color = float4(0.0, 0.0, 0.0, 0.6);
    }
    
    // GPU usage (16.6ms = 100% at 60fps)
    float gpuUsage = clamp(uniforms.gpuTime / 16.6, 0.0, 1.0);
    if (uv.x > gpuPos.x && uv.x < gpuPos.x + barSize.x &&
        uv.y > gpuPos.y && uv.y < gpuPos.y + barSize.y) {
        float fill = (uv.x - gpuPos.x) / barSize.x;
        color = (fill < gpuUsage) ? float4(0.0, 1.0, 0.5, 0.9) : float4(0.2, 0.2, 0.2, 0.7);
    }
    
    // CPU usage
    float cpuUsage = clamp(uniforms.cpuTime / 16.6, 0.0, 1.0);
    if (uv.x > cpuPos.x && uv.x < cpuPos.x + barSize.x &&
        uv.y > cpuPos.y && uv.y < cpuPos.y + barSize.y) {
        float fill = (uv.x - cpuPos.x) / barSize.x;
        color = (fill < cpuUsage) ? float4(1.0, 0.8, 0.0, 0.9) : float4(0.2, 0.2, 0.2, 0.7);
    }
    
    return color;
}
