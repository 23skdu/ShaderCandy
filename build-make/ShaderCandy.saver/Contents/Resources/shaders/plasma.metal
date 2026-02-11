// Plasma effect - colorful flowing waves
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * 0.5;
    
    // Create plasma effect with multiple sine waves
    float v = sin(uv.x * 10.0 + t);
    v += sin(uv.y * 10.0 + t * 1.2);
    v += sin((uv.x + uv.y) * 10.0 + t * 0.8);
    v += sin(length(uv) * 10.0 + t * 1.5);
    v *= 0.25;
    
    // Map to colors
    float3 color = float3(
        0.5 + 0.5 * sin(v * 3.14159 + t),
        0.5 + 0.5 * sin(v * 3.14159 + t + 2.0),
        0.5 + 0.5 * sin(v * 3.14159 + t + 4.0)
    );
    
    return float4(color, uniforms.alpha);
}
