// Aquatic Animals - Underwater caustics and bubbles

#include "ShaderInterop.h"
#include <metal_stdlib>
using namespace metal;

/* struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float speed;
    float intensity;
    float underwater;
    float bubbles;
    float caustics;
}; */



float3 underwaterEffect(float2 uv, float time) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float underwater = sin(p.y * 8.0 + time * 2.0) * 0.5 + 0.5;
    underwater = smoothstep(0.4, 0.6, underwater);
    
    float3 underwaterColor = float3(0.0, 0.2, 0.3);
    underwaterColor = mix(underwaterColor, float3(0.0, 0.3, 0.4), underwater);
    
    float underwaterNoise = custom_noise(p * 5.0 + time * 1.0);
    underwaterColor *= underwaterNoise * 0.5 + 0.5;
    
    return underwaterColor * underwater;
}

float3 bubbles(float2 uv, float time) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float bubble = custom_noise(p * 10.0 + time * 3.0);
    bubble = step(0.8, bubble);
    
    float3 bubbleColor = float3(1.0, 1.0, 1.0);
    bubbleColor *= bubble;
    
    return bubbleColor * bubble;
}

float3 caustics(float2 uv, float time) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float caustic = sin(p.x * 20.0 + time * 4.0) * 0.5 + 0.5;
    caustic *= sin(p.y * 15.0 + time * 3.0) * 0.5 + 0.5;
    caustic = smoothstep(0.4, 0.6, caustic);
    
    float3 causticColor = float3(1.0, 0.8, 0.6);
    causticColor *= caustic;
    
    return causticColor * caustic;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                                  constant Uniforms& u [[buffer(0)]]) {
    // Injected default values for missing uniforms
    float u_underwater = 1.0;
    float u_bubbles = 1.0;
    float u_caustics = 1.0;

    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * u.speed * 0.2;
    
    // Underwater gradient
    float3 underwaterColor = float3(0.0, 0.1, 0.2);
    float underwaterGradient = length(p);
    underwaterGradient = smoothstep(0.0, 0.8, underwaterGradient);
    underwaterColor = mix(underwaterColor, float3(0.0, 0.2, 0.3), underwaterGradient);
    
    // Underwater effect
    float3 underwater = underwaterEffect(uv, t * u_underwater);
    underwaterColor += underwater * 0.6;
    
    // Bubbles
    float3 bubbleEffect = bubbles(uv, t * u_bubbles);
    underwaterColor += bubbleEffect * 0.4;
    
    // Caustics
    float3 causticEffect = caustics(uv, t * u_caustics);
    underwaterColor += causticEffect * 0.3;
    
    // Fish-like patterns
    float fishPattern = sin(p.y * 12.0 + t * 2.0) * 0.5 + 0.5;
    fishPattern = smoothstep(0.4, 0.6, fishPattern);
    
    float3 fishColor = float3(0.2, 0.4, 0.6);
    fishColor = mix(fishColor, float3(0.3, 0.5, 0.7), fishPattern);
    
    underwaterColor += fishColor * fishPattern * 0.3;
    
    // Intensity effects
    underwaterColor *= u.intensity * 0.8 + 0.2;
    
    return float4(underwaterColor, 1.0);
}