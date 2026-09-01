fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    // Simple raymarching through a noise field
    float3 ro = float3(0.0, 0.0, uniforms.time * 0.2); // Ray origin
    float3 rd = normalize(float3(uv, 1.2)); // Ray direction
    
    float density = 0.0;
    float3 cloudCol = float3(0.0);
    
    float t = 0.0;
    for(int i = 0; i < 48; i++) {
        float3 p = ro + rd * t;
        
        // Multi-layered noise for clouds
        float f = ShaderUtils::fbm(p * 0.8 + uniforms.time * 0.05, 3);
        f = smoothstep(0.2, 0.6, f);
        
        if (f > 0.01) {
            float ld = f * 0.1; // Local density
            density += ld * (1.0 - density);
            
            // Subtle lighting based on density gradient (fake)
            float3 light = float3(0.6, 0.7, 1.0) * (1.0 - f * 0.5);
            cloudCol += light * ld * (1.0 - density);
        }
        
        t += 0.15;
        if (density > 0.99) break;
    }
    
    // Aesthetic sky gradient
    float3 skyCol = mix(float3(0.05, 0.1, 0.25), float3(0.15, 0.3, 0.6), rd.y * 0.5 + 0.5);
    
    // Mix sky and clouds
    float3 finalCol = mix(skyCol, cloudCol, density);
    
    // Add sun glow
    float3 sunPos = normalize(float3(0.5, 0.5, 1.0));
    float sun = pow(max(dot(rd, sunPos), 0.0), 32.0);
    finalCol += float3(1.0, 0.9, 0.7) * sun;
    
    return float4(finalCol, uniforms.alpha);
}
