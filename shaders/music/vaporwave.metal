#include "ShaderInterop.h"


// Vaporwave - Retro 80s aesthetic with neon grids and sunsets

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

float sdCircle(float2 p, float r) {
    return length(p) - r;
}

float gridLine(float2 p, float spacing) {
    float2 g = abs(fract(p / spacing - 0.5) - 0.5) * spacing;
    return min(g.x, g.y);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                                  constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.3;
    
    float2 gridUV = p;
    gridUV.y += 0.5;
    gridUV.y *= 3.0;
    float2 gridP = float2(gridUV.x * 4.0, gridUV.y * 2.0 + t * 2.0);
    float g = gridLine(gridP, 0.1);
    g = smoothstep(0.02, 0.0, g);
    
    float gridFade = smoothstep(1.5, -0.5, p.y);
    g *= gridFade;
    
    float2 sunPos = float2(0.0, 0.3);
    float sun = sdCircle(p - sunPos, 0.6);
    float sunGlow = smoothstep(0.0, 0.5, sun);
    
    float stripes = sin((p.y - sunPos.y + 0.6) * 30.0);
    stripes = step(0.0, stripes) * step(p.y, sunPos.y + 0.1);
    stripes *= step(sunPos.y - 0.6, p.y);
    
    float3 skyTop = float3(0.1, 0.0, 0.3);
    float3 skyBottom = float3(1.0, 0.4, 0.7);
    float3 sky = mix(skyBottom, skyTop, uv.y);
    
    float3 sunColor = mix(float3(1.0, 0.8, 0.0), float3(1.0, 0.3, 0.5), uv.y);
    sunColor = mix(sunColor, float3(1.0, 0.9, 0.3), stripes);
    
    float3 col = sky;
    col = mix(col, sunColor, sunGlow);
    
    float3 gridColor = float3(0.0, 0.8, 1.0);
    col = mix(col, gridColor, g * 0.7);
    
    float bassPulse = u.bass * 0.3;
    col += gridColor * g * bassPulse;
    
    float scanline = sin(uv.y * u.resolution.y * 2.0) * 0.04;
    col -= scanline;
    
    return float4(col, 1.0);
}
