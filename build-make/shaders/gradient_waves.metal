// Gradient waves - smooth flowing color gradients
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float t = uniforms.time * uniforms.speed * 0.2;
    
    // Create flowing waves
    float wave1 = sin(uv.x * 5.0 + t) * 0.5 + 0.5;
    float wave2 = sin(uv.y * 5.0 + t * 1.3) * 0.5 + 0.5;
    float wave3 = sin((uv.x + uv.y) * 3.0 + t * 0.7) * 0.5 + 0.5;
    
    // Combine waves for smooth gradients
    float r = wave1 * 0.5 + wave3 * 0.5;
    float g = wave2 * 0.6 + wave1 * 0.4;
    float b = wave3 * 0.7 + wave2 * 0.3;
    
    // Add some brightness variation
    float brightness = 0.7 + 0.3 * sin(t * 0.5);
    
    float3 color = float3(r, g, b) * brightness;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
