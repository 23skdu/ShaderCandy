// Mandelbrot Set 2D
// Deep zoom and smooth coloring

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.y > 0 ? uniforms.resolution.x / uniforms.resolution.y : 1.0;
    uv.x *= aspect;
    
    float t = uniforms.time * 0.2;
    
    // Zoom in on an interesting coordinate
    float zoom = pow(2.0, 1.0 + 5.0 * (0.5 + 0.5 * sin(t * 0.5)));
    float2 center = float2(-0.74364388703, 0.13182590421);
    float2 c = center + uv / zoom;
    
    float2 z = float2(0.0);
    float iter = 0.0;
    float max_iter = 256.0;
    
    for (int i = 0; i < 256; i++) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (length(z) > 100.0) break;
        iter += 1.0;
    }
    
    float3 color = float3(0.0);
    if (iter < max_iter) {
        float dist = length(z);
        float smooth_iter = iter - log2(log(dist) / log(100.0));
        
        color = 0.5 + 0.5 * sin(float3(0.05, 0.1, 0.15) * smooth_iter + t * 2.0);
        // Add some contrast
        color = pow(color, float3(1.2));
    }
    
    return float4(color, uniforms.alpha);
}
