// Soul - Smooth, warm, emotional aesthetic

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

float fbm(float2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

fragment float4 soul_fragment(VertexOut in [[stage_in]],
                              constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.25;
    
    // Warm, smooth background gradient
    float3 col = float3(0.1, 0.05, 0.15);  // Deep purple
    col = mix(col, float3(0.2, 0.1, 0.25), uv.y);
    col = mix(col, float3(0.3, 0.15, 0.2), uv.x * 0.5);
    
    // Velvet-like texture
    float velvet = fbm(p * 3.0 + t * 0.2);
    col += float3(0.1, 0.05, 0.1) * velvet;
    
    // Smooth flowing ribbons (like silk)
    float2 ribP = p;
    ribP.x += sin(p.y * 3.0 + t) * 0.3;
    ribP.y += cos(p.x * 2.0 + t * 0.7) * 0.2;
    
    float rib = sin(ribP.x * 4.0 + ribP.y * 2.0 + t);
    rib = smoothstep(0.3, 0.5, rib);
    
    // Soul colors - warm purple to pink
    float3 ribCol = mix(float3(0.4, 0.1, 0.4), float3(0.8, 0.3, 0.5), uv.y);
    ribCol = mix(ribCol, float3(0.6, 0.2, 0.3), sin(t * 0.5) * 0.3 + 0.3);
    col = mix(col, ribCol, rib * 0.4);
    
    // Gentle bass pulse (subtle)
    float bassPulse = u.bass * 0.15;
    col += float3(0.15, 0.05, 0.1) * bassPulse;
    
    // Soft light orbs (like stage lights through fog)
    float numOrbs = 3.0;
    for (float i = 0.0; i < numOrbs; i++) {
        float orbX = sin(t * 0.3 + i * 2.0) * 0.5;
        float orbY = cos(t * 0.2 + i * 1.5) * 0.3 + 0.2;
        float2 orbPos = float2(orbX, orbY);
        
        float dist = length(p - orbPos);
        float orb = smoothstep(0.4, 0.0, dist);
        orb *= smoothstep(0.0, 0.2, dist);  // Soft falloff
        
        // Warm amber/gold light
        float3 orbCol = float3(1.0, 0.8, 0.4);
        orbCol = mix(orbCol, float3(1.0, 0.5, 0.3), i / numOrbs);
        col += orbCol * orb * 0.3;
    }
    
    // Vinyl record in corner
    float2 recordPos = float2(-0.6, -0.5);
    float recordDist = length(p - recordPos);
    float record = smoothstep(0.35, 0.33, recordDist);
    float recordInner = smoothstep(0.1, 0.08, recordDist);
    
    // Record grooves
    float groove = sin(recordDist * 40.0 + t * 2.0) * 0.5 + 0.5;
    groove = smoothstep(0.3, 0.7, groove);
    
    float3 recordCol = float3(0.05, 0.05, 0.05);
    recordCol = mix(recordCol, float3(0.15, 0.1, 0.1), groove * (1.0 - recordInner));
    recordCol = mix(recordCol, float3(0.8, 0.6, 0.2), recordInner);  // Label
    
    col = mix(col, recordCol, record);
    
    // Smooth mid-range visualization
    float waveY = sin(p.x * 8.0 + t * 1.5) * 0.05 * (1.0 + u.mid);
    float wave = smoothstep(0.02, 0.0, abs(p.y - waveY - 0.6));
    col += float3(0.8, 0.4, 0.3) * wave * 0.3;
    
    // Treble shimmer (delicate)
    float shimmer = noise(p * 20.0 + t * 3.0);
    shimmer = pow(shimmer, 4.0) * u.treble;
    col += float3(1.0, 0.9, 0.8) * shimmer * 0.3;
    
    // Soft glow around center
    float centerGlow = smoothstep(0.8, 0.0, length(p));
    col += float3(0.2, 0.1, 0.15) * centerGlow * 0.3;
    
    // Overall warm tint
    col.r *= 1.1;
    col.b *= 0.9;
    
    // Vignette (soft, romantic)
    float vignette = 1.0 - length(uv - 0.5) * 0.5;
    vignette = smoothstep(0.0, 1.0, vignette);
    col *= vignette;
    
    return float4(col, 1.0);
}
