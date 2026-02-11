fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time;
    
    // Zoom
    float zoom = 1.0 + t * 0.1;
    float2 center = float2(-0.745, 0.186); // Interesting point
    
    // Animate center a bit
    center += float2(sin(t * 0.1) * 0.01, cos(t * 0.13) * 0.01);
    
    float2 c = center + uv / pow(2.0, zoom);
    float2 z = c;
    
    int iter = 0;
    const int max_iter = 100;
    
    for(int i = 0; i < max_iter; i++) {
        if(length(z) > 2.0) break;
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        iter++;
    }
    
    float3 col = float3(0.0);
    if (iter < max_iter) {
        float fIter = (float)iter / (float)max_iter;
        col = float3(sin(fIter * 10.0 + t), sin(fIter * 15.0 + t * 1.5), sin(fIter * 20.0 + t * 2.0));
        col = col * 0.5 + 0.5;
    }
    
    return float4(col, uniforms.alpha);
}
