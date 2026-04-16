#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Waterfall
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Background cliff
    float3 cliffColor = float3(0.15, 0.12, 0.1);
    float3 color = cliffColor;
    
    // Cliff edge
    float cliffLeft = -0.3 + sin(p.y * 3.0) * 0.1;
    float cliffRight = 0.3 + sin(p.y * 2.0 + 1.0) * 0.08;
    
    // Waterfall path
    float waterfallX = 0.0 + sin(p.y * 5.0) * 0.05;
    float waterfallWidth = 0.15;
    
    // Water in waterfall
    if (abs(p.x - waterfallX) < waterfallWidth) {
        // Animated water flow
        float flow = fract(p.y * 8.0 - t * 2.0);
        float spray = noise(float2(p.x * 20.0, p.y * 20.0 - t * 5.0));
        
        // Water color
        float3 waterColor = float3(0.6, 0.75, 0.85);
        
        // Foam at edges
        float edgeDist = abs(p.x - waterfallX) / waterfallWidth;
        float foam = smoothstep(0.6, 1.0, edgeDist);
        
        // Add variation
        float ripples = sin(p.y * 30.0 + p.x * 10.0 + t * 3.0) * 0.5 + 0.5;
        
        waterColor = mix(waterColor, float3(1.0), foam * 0.4);
        waterColor += float3(0.3) * ripples * 0.2;
        
        // Mist at bottom
        if (p.y < -0.3) {
            float mist = smoothstep(-0.3, -0.8, p.y);
            float mistNoise = fbm(float3(p * 5.0, t * 0.5), 4);
            waterColor = mix(waterColor, float3(0.8, 0.85, 0.9), mist * mistNoise);
        }
        
        color = waterColor;
    }
    
    // Mist/spray particles
    float2 sprayPos = float2(waterfallX, -0.3);
    for (float i = 0.0; i < 20.0; i++) {
        float seed = i * 3.14;
        float2 dropPos = float2(
            waterfallX + sin(seed + t) * 0.3,
            -0.3 - mod(i * 0.1 + t * 0.5, 0.8)
        );
        float drop = smoothstep(0.05, 0.0, length(p - dropPos));
        color += float3(0.7, 0.8, 0.9) * drop * 0.5;
    }
    
    // Pool at bottom
    if (p.y < -0.6) {
        float poolDist = length(p - float2(waterfallX, -0.7));
        float pool = smoothstep(0.5, 0.0, poolDist);
        
        float3 poolColor = float3(0.2, 0.35, 0.45);
        float ripples = sin(poolDist * 20.0 - t * 2.0) * 0.5 + 0.5;
        poolColor += float3(0.1) * ripples;
        
        color = mix(color, poolColor, pool * 0.7);
    }
    
    // Rocks around waterfall
    float rocks = smoothstep(0.4, 0.35, abs(p.x - waterfallX - 0.2));
    rocks *= smoothstep(-0.8, -0.3, p.y);
    color = mix(color, float3(0.2, 0.18, 0.15), rocks);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
