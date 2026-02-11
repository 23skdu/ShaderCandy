fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float t = uniforms.time;
    
    float3 color = float3(
        0.5 + 0.5 * sin(t + uv.x * 3.14159),
        0.5 + 0.5 * sin(t + uv.y * 3.14159 + 2.0),
        0.5 + 0.5 * sin(t + length(uv - 0.5) * 6.0)
    );
    
    return float4(color, uniforms.alpha);
}
