// Aquatic Animals - Underwater caustics and bubbles with 3D depth layers

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



// Multi-layer wave function
float waveLayer(float2 uv, float time, float speed, float freq, float amp) {
    float2 p = uv;
    float wave = sin(p.x * freq + time * speed) * amp;
    wave += sin(p.x * freq * 2.0 + time * speed * 1.5) * amp * 0.5;
    wave += sin(p.y * freq * 0.5 + time * speed * 0.8) * amp * 0.3;
    return wave;
}

// 3D underwater layers
float3 deepWaterLayer(float2 uv, float time, float depth) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    // Multiple wave layers at different depths
    float wave1 = waveLayer(p, time + depth, 1.0 + depth * 0.5, 4.0 + depth * 2.0, 0.1);
    float wave2 = waveLayer(p, time * 0.7 + depth * 1.5, 0.8, 6.0 + depth * 3.0, 0.08);
    float wave3 = waveLayer(p, time * 0.5 + depth * 2.0, 0.6, 8.0 + depth * 4.0, 0.05);
    
    float combinedWave = wave1 + wave2 * 0.7 + wave3 * 0.4;
    
    // Dark blue gradient based on depth
    float3 deepColor = mix(
        float3(0.0, 0.1, 0.25),  // Surface dark blue
        float3(0.0, 0.02, 0.1),  // Deep ocean
        depth
    );
    
    float3 waveColor = mix(
        float3(0.0, 0.2, 0.4),   // Wave highlights
        float3(0.0, 0.05, 0.2),  // Wave shadows
        combinedWave * 0.5 + 0.5
    );
    
    return mix(deepColor, waveColor, 0.4 + combinedWave * 0.3);
}

// Enhanced caustics
float3 causticsLayer(float2 uv, float time, float depth) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float caustic = 0.0;
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 offset = float2(
            sin(time * (1.0 + fi * 0.3) + fi * 2.0),
            cos(time * (0.8 + fi * 0.2) + fi * 1.5)
        ) * 0.3;
        
        caustic += sin((p.x + offset.x) * (15.0 + fi * 5.0) + time * (3.0 + fi));
        caustic *= sin((p.y + offset.y) * (12.0 + fi * 4.0) + time * (2.5 + fi * 0.5));
    }
    
    caustic = smoothstep(0.3, 0.7, caustic * 0.5 + 0.5);
    
    // Golden caustics that fade with depth
    float3 causticColor = float3(1.0, 0.9, 0.7) * (1.0 - depth * 0.5);
    return causticColor * caustic * (1.0 - depth * 0.3);
}

// 3D bubbles with depth
float3 bubbleLayer(float2 uv, float time, float depth) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float3 bubbles = float3(0.0);
    
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float2 bubblePos = p;
        
        // Each bubble at different depth
        float bubbleDepth = fract(fi * 0.618 + depth * 0.5);
        float speed = 0.5 + bubbleDepth * 0.5;
        float size = 0.02 + bubbleDepth * 0.03;
        
        // Rising motion
        bubblePos.y += time * speed * (0.3 + bubbleDepth * 0.2);
        bubblePos.y = fract(bubblePos.y + fi * 0.3) - 0.5;
        
        // Horizontal drift
        bubblePos.x += sin(time * 0.5 + fi * 3.0) * 0.1 * (1.0 + bubbleDepth);
        
        // Bubble instance spacing
        float2 gridPos = float2(
            mod(fi * 0.7 + sin(fi * 2.0) * 0.5, 2.0) - 1.0,
            0.0
        );
        bubblePos -= gridPos * (0.5 + bubbleDepth * 0.5);
        
        float dist = length(bubblePos);
        float bubble = smoothstep(size, size * 0.7, dist);
        
        // Bubble highlight
        float highlight = smoothstep(size * 0.3, size * 0.1, length(bubblePos - float2(-size * 0.3, size * 0.3)));
        
        // Depth-based color
        float3 bubbleColor = mix(
            float3(0.8, 0.9, 1.0),
            float3(0.6, 0.7, 0.9),
            bubbleDepth
        );
        
        bubbles += bubbleColor * bubble * (0.5 + bubbleDepth * 0.5);
        bubbles += float3(1.0) * highlight * bubble * 0.8;
    }
    
    return bubbles;
}

// Sea creatures (fish silhouettes)
float3 fishLayer(float2 uv, float time, float depth) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float3 fishCol = float3(0.0);
    
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float fishDepth = fract(fi * 0.4 + depth * 0.3);
        
        float2 fishPos = p;
        fishPos.x += time * (0.2 + fishDepth * 0.1) + fi * 0.8;
        fishPos.x = mod(fishPos.x + 2.0, 4.0) - 2.0;
        fishPos.y += sin(time * 2.0 + fi * 3.0) * 0.1 * (1.0 + fishDepth);
        
        // Fish body (elongated circle)
        float fishBody = smoothstep(0.15, 0.12, length(float2(fishPos.x * 2.0, fishPos.y)));
        // Tail
        float fishTail = smoothstep(0.08, 0.05, length(fishPos - float2(-0.12, 0.0) + float2(0.0, sin(time * 10.0 + fi) * 0.02)));
        
        float fish = max(fishBody, fishTail * 0.7);
        
        // Dark silhouette that fades with depth
        float3 fishColor = mix(
            float3(0.1, 0.2, 0.3),
            float3(0.05, 0.1, 0.15),
            fishDepth
        );
        
        fishCol += fishColor * fish * (0.6 + fishDepth * 0.4);
    }
    
    return fishCol;
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
    
    // 3D depth layers
    float3 finalColor = float3(0.0);
    
    // Background/far layer
    float3 farLayer = deepWaterLayer(uv, t * u_underwater, 0.8);
    farLayer += causticsLayer(uv, t * u_caustics, 0.8) * 0.3;
    farLayer += fishLayer(uv, t, 0.8) * 0.5;
    
    // Middle layer
    float3 midLayer = deepWaterLayer(uv, t * u_underwater * 1.2 + 0.5, 0.5);
    midLayer += causticsLayer(uv, t * u_caustics * 1.1 + 0.3, 0.5) * 0.5;
    midLayer += bubbleLayer(uv, t * u_bubbles, 0.5) * 0.4;
    midLayer += fishLayer(uv, t + 1.0, 0.5) * 0.7;
    
    // Near layer
    float3 nearLayer = deepWaterLayer(uv, t * u_underwater * 1.5 + 1.0, 0.2);
    nearLayer += causticsLayer(uv, t * u_caustics * 1.3 + 0.7, 0.2) * 0.7;
    nearLayer += bubbleLayer(uv, t * u_bubbles * 1.5, 0.2) * 0.8;
    
    // Composite layers with depth fog
    finalColor = farLayer * 0.6;
    finalColor = mix(finalColor, midLayer, 0.7);
    finalColor = mix(finalColor, nearLayer, 0.85);
    
    // Deep water vignette
    float vignette = 1.0 - length(p) * 0.4;
    finalColor *= vignette;
    
    // Underwater gradient overlay
    float3 deepBlue = float3(0.0, 0.05, 0.15);
    finalColor = mix(finalColor, deepBlue, 0.3);
    
    // Additional wave layers on top
    float surfaceWave = sin(p.x * 10.0 + t * 3.0) * 0.5 + 0.5;
    surfaceWave *= sin(p.y * 8.0 + t * 2.0) * 0.5 + 0.5;
    finalColor += float3(0.0, 0.1, 0.2) * surfaceWave * 0.1;
    
    // Intensity effects
    finalColor *= u.intensity * 0.9 + 0.1;
    
    return float4(finalColor, 1.0);
}