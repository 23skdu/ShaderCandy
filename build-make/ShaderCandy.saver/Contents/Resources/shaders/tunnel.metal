// Tunnel effect - hypnotic rotating tunnel
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.y > 0 ? uniforms.resolution.x / uniforms.resolution.y : 1.0;
    uv.x *= aspect;
    float t = uniforms.time * 0.3;
    
    // Convert to polar coordinates
    float angle = atan2(uv.y, uv.x);
    float radius = length(uv);
    
    // Create tunnel effect with safety epsilon
    float tunnel = 0.1 / (radius + 0.001);
    float rotation = angle / 3.14159 + t;
    
    // Stripe pattern
    float stripes = sin(tunnel * 10.0 - t * 2.0) * 0.5 + 0.5;
    float spiral = sin(rotation * 8.0 + tunnel * 5.0) * 0.5 + 0.5;
    
    // Combine patterns
    float pattern = stripes * spiral;
    
    // Color gradient based on angle and depth
    float3 color = float3(
        0.5 + 0.5 * sin(pattern * 6.28 + t),
        0.5 + 0.5 * sin(pattern * 6.28 + t + 2.0),
        0.5 + 0.5 * sin(pattern * 6.28 + t + 4.0)
    );
    
    // Add glow at center
    color += float3(0.2, 0.1, 0.3) * (1.0 - smoothstep(0.0, 0.5, radius));
    
    return float4(color, uniforms.alpha);
}
