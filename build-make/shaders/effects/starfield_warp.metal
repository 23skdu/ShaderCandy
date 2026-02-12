fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    float3 col = float3(0.0);
    
    // Starfield
    for(float i = 0.0; i < 100.0; i++) {
        float z = fract(i * 0.0123 - t * 0.5);
        float fade = 1.0 - z;
        
        float2 st = uv * (0.5 / z);
        float a = atan2(st.y, st.x) + z * 5.0; // Twist
        float r = length(st);
        
        // Pseudo-random pos
        float2 pos = float2(sin(i * 123.4 + a), cos(i * 456.7 + a)) * r;
        
        float d = length(st - pos);
        float size = 0.005 / z;
        
        // Branchless star drawing
        col += float3(1.0, 0.8, 0.5) * fade * max(0.0, 1.0 - d / size) * step(d, size);
    }
    
    // Background nebula
    col += float3(0.1, 0.0, 0.2) * (0.5 + 0.5 * sin(uv.y * 5.0 + t));
    
    col *= uniforms.intensity;
    return float4(col, uniforms.alpha);
}
