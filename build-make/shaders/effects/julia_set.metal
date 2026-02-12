// Julia Set 2D
// Smooth coloring implementation

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.y > 0 ? uniforms.resolution.x / uniforms.resolution.y : 1.0;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed * 0.5;
    
    // Animate the Julia constant
    float2 c = float2(0.355 + 0.1 * sin(t), 0.355 + 0.1 * cos(t * 0.7));
    if (uniforms.mouseButtons > 0.0) {
        c = uniforms.mouse * 2.0 - 1.0;
    }
    
    float2 z = uv * 1.5;
    float iter = 0.0;
    float max_iter = 128.0;
    
    for (int i = 0; i < 128; i++) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (length(z) > 4.0) break;
        iter += 1.0;
    }
    
    float3 color = float3(0.0);
    if (iter < max_iter) {
        // Smooth coloring
        float dist = length(z);
        float smooth_iter = iter - log2(log(dist + 0.001) / log(2.0));
        
        color = 0.5 + 0.5 * sin(float3(0.1, 0.2, 0.3) * smooth_iter + t);
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
