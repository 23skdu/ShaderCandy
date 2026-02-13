// HipHop - Urban aesthetic with street vibes

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float speed;
    float intensity;
    float bass;
    float mid;
    float treble;
};

float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

float noise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

fragment float4 hiphop_fragment(VertexOut in [[stage_in]],
                                constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.4;
    
    // Graffiti-style background
    float3 bgCol = float3(0.05, 0.05, 0.1);
    float n = noise(p * 3.0 + t * 0.5);
    bgCol = mix(bgCol, float3(0.15, 0.05, 0.2), n);
    
    // Dynamic graffiti lines
    float2 lineP = p;
    lineP.x += sin(p.y * 8.0 + t * 2.0) * 0.3;
    lineP.x += sin(p.y * 3.0 - t * 1.5) * 0.2;
    
    float lines = abs(sin(lineP.x * 15.0 + t * 3.0));
    lines = smoothstep(0.8, 1.0, lines);
    
    float3 graffitiColors[4] = {
        float3(1.0, 0.2, 0.4),   // Hot pink
        float3(0.2, 1.0, 0.5),    // Lime green
        float3(1.0, 0.8, 0.0),    // Gold
        float3(0.0, 0.8, 1.0)      // Cyan
    };
    
    float colorIdx = floor(random(floor(p * 2.0 + t)) * 4.0);
    float3 lineCol = graffitiColors[int(colorIdx)];
    lineCol = mix(lineCol, graffitiColors[int(mod(colorIdx + 1.0, 4.0))], random(p + t));
    
    float3 col = bgCol;
    col = mix(col, lineCol, lines * 0.8);
    
    // Beat pulse effect
    float pulse = u.bass * 0.5;
    col += lineCol * pulse * lines;
    
    // Treble sparkles
    float sparkle = noise(p * 20.0 + t * 5.0);
    sparkle = step(0.85, sparkle) * u.treble;
    col += float3(1.0) * sparkle;
    
    // Vinyl record in center
    float recordDist = length(p);
    float record = smoothstep(0.5, 0.48, recordDist);
    float recordInner = smoothstep(0.15, 0.13, recordDist);
    float3 recordCol = float3(0.1, 0.1, 0.1);
    recordCol = mix(recordCol, float3(0.8, 0.1, 0.1), record - recordInner);
    
    // Vinyl grooves
    float groove = sin(recordDist * 50.0 + t * 10.0) * 0.5 + 0.5;
    groove = smoothstep(0.3, 0.7, groove);
    recordCol = mix(recordCol, float3(0.05), groove * (1.0 - recordInner) * record);
    
    col = mix(col, recordCol, record);
    col = mix(col, float3(1.0, 0.9, 0.7), recordInner); // Label
    
    // Bass vibration
    float vibration = sin(atan(p.y, p.x) * 20.0 + t * 8.0) * u.bass * 0.1;
    col += lineCol * vibration * (1.0 - record);
    
    return float4(col, 1.0);
}
