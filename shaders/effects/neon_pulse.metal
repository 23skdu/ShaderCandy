fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    float3 color = float3(0.0);
    float r = length(uv);
    float a = atan2(uv.y, uv.x);
    
    float audioPulse = uniforms.volume * 2.0 + uniforms.bass * 1.5;
    
    for(float i = 0.0; i < 3.0; i++) {
        float f = t + i * 2.0;
        float s = sin(f) * 0.5 + 0.5;
        float sweep = sin(r * 10.0 - audioPulse + t * 2.0 + i) + sin(a * 5.0 + t) * 0.5;
        float w = (0.02 + audioPulse * 0.05) / abs(sweep);
        color += float3(s, fract(s + 0.3), fract(s + 0.6)) * w;
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
