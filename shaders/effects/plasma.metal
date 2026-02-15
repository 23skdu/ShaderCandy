#include "ShaderInterop.h"

// Plasma Fractal - Classic demo scene effect with moving color bands

using namespace metal;

float noise(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = noise(i);
    float b = noise(i + float2(1.0, 0.0));
    float c = noise(i + float2(0.0, 1.0));
    float d = noise(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(float2 p) {
    float f = 0.0;
    float w = 0.5;
    
    for(int i = 0; i < 6; i++) {
        f += w * smoothNoise(p);
        p *= 2.0;
        w *= 0.5;
    }
    
    return f;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 6.0;
    
    float t = u.time * 0.3;
    
    // Multiple plasma layers
    float v1 = sin(p.x + t);
    float v2 = sin(p.y + t * 0.5);
    float v3 = sin(p.x + p.y + t * 0.7);
    float v4 = sin(sqrt(p.x * p.x + p.y * p.y) + t);
    
    float v5 = fbm(p + float2(t * 0.2, t * 0.1));
    float v6 = fbm(p * 2.0 - float2(t * 0.3, t * 0.15));
    
    // Combine
    float plasma = v1 + v2 + v3 + v4 + v5 * 2.0 + v6;
    plasma = (plasma + 5.0) / 10.0;
    
    // Color mapping
    float r = sin(plasma * 3.14159 + 0.0);
    float g = sin(plasma * 3.14159 + 2.094);
    float b = sin(plasma * 3.14159 + 4.188);
    
    float3 col = float3(r, g, b);
    col = col * 0.5 + 0.5;
    
    // Add glow
    col *= 1.0 + 0.3 * sin(plasma * 10.0);
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.8;
    col *= vig;
    
    return float4(col * u.intensity, 1.0);
}
