fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time;
    
    float m = 1.0;
    float3 col = float3(0.0);
    
    // Voronoi
    for(int i = 0; i < 20; i++) {
        float2 p = float2(sin(t * 0.1 + i * 132.3), cos(t * 0.15 + i * 45.1));
        float d = length(uv - p);
        m = min(m, d);
    }
    
    col = float3(1.0 - m);
    col = pow(col, float3(3.0));
    col *= float3(0.5 + 0.5 * sin(t), 0.5 + 0.5 * cos(t), 0.8);
    
    // Edges (Branchless)
    col += 0.5 * step(m, 0.05);
    
    return float4(col, uniforms.alpha);
}
