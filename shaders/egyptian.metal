#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Ancient Egyptian theme
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Sandstone background
    float3 color = float3(0.75, 0.6, 0.4);
    
    // Add sandstone texture
    float sandNoise = noise(p * 30.0) * 0.1;
    color -= sandNoise;
    
    // Hieroglyphics pattern (simplified)
    float2 grid = fract(p * 8.0) - 0.5;
    float glyph = smoothstep(0.3, 0.25, length(grid));
    
    // Vary glyphs
    float2 cellID = floor(p * 8.0);
    float glyphType = hash(cellID.x + cellID.y * 100.0);
    
    if (glyphType > 0.5 && uv.y > 0.3 && uv.y < 0.8) {
        color = mix(color, float3(0.5, 0.35, 0.2), glyph * 0.6);
    }
    
    // Gold accent lines
    float2 lineP = fract(p * 4.0);
    float lines = smoothstep(0.48, 0.5, max(lineP.x, lineP.y));
    color = mix(color, float3(0.85, 0.7, 0.3), lines * 0.4);
    
    // Sun disk (Ra)
    float2 sunPos = float2(0.0, 0.5);
    float sun = smoothstep(0.2, 0.0, length(p - sunPos));
    float sunGlow = smoothstep(0.5, 0.0, length(p - sunPos));
    
    color += float3(1.0, 0.9, 0.6) * sun;
    color += float3(1.0, 0.7, 0.3) * sunGlow * 0.2;
    
    // Pyramid silhouette
    if (p.y < -0.4) {
        float pyramidX = 0.0;
        float pyramidH = 0.4;
        float pyramidW = 0.8;
        
        float pyX = (p.y + 0.4) * pyramidW / pyramidH;
        if (abs(p.x - pyramidX) < pyX && p.y > -0.8) {
            color = float3(0.6, 0.45, 0.3);
        }
    }
    
    // Ankh symbol in center
    float2 ankhPos = float2(0.0, 0.1);
    float ankhDist = length(p - ankhPos);
    float ankh = smoothstep(0.15, 0.14, ankhDist) - smoothstep(0.14, 0.13, ankhDist);
    ankh += smoothstep(0.06, 0.05, abs(p.x - ankhPos.x)) * step(abs(p.y - ankhPos.y), 0.15);
    
    color = mix(color, float3(0.85, 0.7, 0.3), ankh * 0.8);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
