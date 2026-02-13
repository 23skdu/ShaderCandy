// Jazz - Smooth flowing curves with warm brass tones and blue-purple palette

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

float noise(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = noise(i);
    float b = noise(i + float2(1.0, 0.0));
    float c = noise(i + float2(0.0, 1.0));
    float d = noise(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * smoothNoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

fragment float4 jazz_fragment(VertexOut in [[stage_in]],
                          constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float t = u.time * 0.2;
    
    // Flowing curves (saxophone-esque)
    float2 p = uv * 3.0;
    p.x += sin(p.y * 2.0 + t) * 0.3;
    p.y += cos(p.x * 1.5 + t * 0.7) * 0.2;
    
    float n = fbm(p + t * 0.5);
    
    // Warm brass colors
    float3 col1 = float3(0.9, 0.6, 0.2);  // Gold/brass
    float3 col2 = float3(0.4, 0.2, 0.5);  // Purple
    float3 col3 = float3(0.1, 0.3, 0.6);  // Blue
    
    float3 col = mix(col3, col2, n);
    col = mix(col, col1, smoothstep(0.4, 0.7, n));
    
    // Add shimmer from treble
    col += float3(0.1, 0.08, 0.05) * u.treble * sin(uv.x * 20.0 + t * 3.0);
    
    // Bass pulse
    col *= 1.0 + u.bass * 0.3;
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.8;
    col *= vig;
    
    return float4(col, 1.0);
}
