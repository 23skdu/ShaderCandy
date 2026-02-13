// Reggae - Laid-back vibes with green/gold山水 patterns

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
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

fragment float4 reggae_fragment(VertexOut in [[stage_in]],
                                constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.2;
    
    // Base gradient - sunset over Jamaica hills
    float3 skyTop = float3(0.1, 0.3, 0.1);    // Dark green
    float3 skyMid = float3(0.9, 0.7, 0.2);     // Golden yellow
    float3 skyBottom = float3(0.1, 0.4, 0.1);  // Grass green
    
    float3 col = mix(skyBottom, skyMid, smoothstep(0.0, 0.5, uv.y));
    col = mix(col, skyTop, smoothstep(0.5, 1.0, uv.y));
    
    // Rolling hills (山水 - "san sui" style)
    float hillY = 0.3;
    for (int i = 0; i < 3; i++) {
        float hillX = float(i) * 0.8 - 0.8;
        float hillWave = sin(p.x * 3.0 + t * 0.5 + float(i)) * 0.15;
        float hill = smoothstep(hillY + hillWave + 0.1, hillY + hillWave - 0.1, p.y + float(i) * 0.2);
        float3 hillCol = mix(float3(0.05, 0.25, 0.05), float3(0.1, 0.4, 0.1), float(i) / 3.0);
        col = mix(col, hillCol, 1.0 - hill);
        hillY += 0.25;
    }
    
    // Sun glow
    float2 sunPos = float2(0.5, 0.7);
    float sunDist = length(p - sunPos);
    float sun = smoothstep(0.4, 0.0, sunDist);
    float3 sunCol = float3(1.0, 0.85, 0.2);  // Golden sun
    col = mix(col, sunCol, sun * 0.8);
    
    // Floating cannabis leaf pattern (subtle)
    float2 leafP = p;
    leafP.x += sin(p.y * 5.0 + t) * 0.2;
    leafP.y += t * 0.1;
    
    float leaf = sin(leafP.x * 8.0) * sin(leafP.y * 8.0 + leafP.x * 4.0);
    leaf = smoothstep(0.3, 0.5, leaf);
    float3 leafCol = float3(0.1, 0.6, 0.1);
    col = mix(col, leafCol, leaf * 0.15 * u.intensity);
    
    // Gold accents - red, gold, green stripes
    float stripeY = fract(p.y * 4.0 - t * 0.3);
    float stripes = step(0.9, stripeY) + step(stripeY, 0.1);
    float3 stripeCol = float3(0.8, 0.6, 0.0);  // Gold
    stripeCol = mix(stripeCol, float3(0.8, 0.1, 0.1), step(0.95, fract(p.y * 4.0 - t * 0.3 - 0.33)));  // Red
    stripeCol = mix(stripeCol, float3(0.1, 0.5, 0.1), step(0.95, fract(p.y * 4.0 - t * 0.3 - 0.66)));  // Green
    col = mix(col, stripeCol, stripes * 0.3);
    
    // Bass drop effect - screen shake
    float shake = u.bass * 0.05;
    col = mix(col, col * 1.2, u.bass * 0.3);
    
    // Treble - star twinkle
    float2 starP = p * 10.0;
    float star = noise(starP + t * 2.0);
    star = step(0.85, star) * u.treble;
    col += float3(1.0, 0.9, 0.5) * star;
    
    // Mid frequencies - gentle wave motion
    float wave = sin(p.x * 10.0 + t * 2.0) * 0.5 + 0.5;
    col += float3(0.0, 0.2, 0.0) * wave * u.mid * 0.2;
    
    // Vignette
    float vignette = 1.0 - length(uv - 0.5) * 0.8;
    col *= vignette;
    
    return float4(col, 1.0);
}
