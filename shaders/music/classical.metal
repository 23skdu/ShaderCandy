#include "ShaderInterop.h"


// Classical - Elegant flowing ribbons with gold and ivory tones

#include <metal_stdlib>
using namespace metal;

/* struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float speed;
    float intensity;
    float bass;
    float mid;
    float treble;
}; */

float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                           constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.3;
    
    float3 col = float3(0.02, 0.01, 0.03);
    
    // Elegant ribbon curves
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float offset = fi * 0.5;
        
        float2 ribbonP = p;
        ribbonP.x += sin(ribbonP.y + t + offset * 3.0) * 0.4;
        ribbonP.y += cos(ribbonP.x * 2.0 + t * 0.7 + offset) * 0.2;
        
        float ribbon = sdBox(ribbonP - float2(sin(t + offset) * 0.3, fi * 0.3 - 0.4), float2(0.02, 0.3));
        ribbon = smoothstep(0.02, 0.0, ribbon);
        
        // Gold to ivory gradient
        float3 ribbonCol = mix(float3(0.9, 0.8, 0.5), float3(1.0, 0.95, 0.85), uv.y);
        col = mix(col, ribbonCol, ribbon * 0.6);
    }
    
    // Soft ambient glow
    col += float3(0.1, 0.08, 0.12) * (1.0 - length(p) * 0.5);
    
    // Bass adds depth
    col *= 1.0 + u.bass * 0.2;
    
    return float4(col, 1.0);
}
