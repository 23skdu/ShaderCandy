fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time;
    
    float3 col = float3(0.0);
    
    // Smooth plasma
    for(float i = 1.0; i < 4.0; i++) {
        uv.x += 0.3 / i * sin(i * 3.0 * uv.y + t);
        uv.y += 0.3 / i * cos(i * 3.0 * uv.x + t);
        float d = length(uv - float2(sin(t * 0.3) * 0.5, cos(t * 0.2) * 0.5));
        
        col.r = sin(d * 10.0 + t + 1.0);
        col.g = sin(d * 10.0 + t + 2.0);
        col.b = sin(d * 10.0 + t + 3.0);
    }
    
    col = col * 0.5 + 0.5;
    
    return float4(col, uniforms.alpha);
}
