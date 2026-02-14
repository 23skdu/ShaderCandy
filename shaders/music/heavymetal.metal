// Heavy Metal - Aggressive dark red/black with lightning and chaos

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

float custom_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}


float custom_fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 6; i++) {
        v += a * custom_noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                            constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 1.5;
    
    // Chaotic custom_noise (aggressive)
    float2 q = p;
    q.x += sin(p.y * 5.0 + t * 2.0) * 0.5;
    q.y += cos(p.x * 4.0 + t * 1.5) * 0.5;
    
    float n = custom_fbm(q * 3.0 + t);
    n = pow(n, 2.0);
    
    // Dark base with red
    float3 col = float3(0.02, 0.0, 0.0);
    col = mix(col, float3(0.4, 0.0, 0.0), n);
    col = mix(col, float3(0.8, 0.2, 0.0), pow(n, 3.0));
    
    // Lightning flashes
    float lightning = step(0.97, custom_hash(float2(floor(t * 10.0), 0.0)));
    col += float3(0.9, 0.8, 0.9) * lightning * n;
    
    // Bass intensity
    col *= 1.0 + u.bass * 0.5;
    
    // Treble sparks
    col += float3(0.3, 0.1, 0.0) * u.treble * step(0.7, n);
    
    return float4(col, 1.0);
}
