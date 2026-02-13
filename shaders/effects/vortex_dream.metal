//
//  vortex_dream.metal
//  ShaderCandy
//
//  Infinite spiraling vortex of glowing particles and light
//

using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float r = length(uv);
    float a = atan2(uv.y, uv.x);
    
    float3 color = float3(0.0);
    
    // Spiral layers
    for (float i = 0.0; i < 5.0; i++) {
        float spiral = a + log(r + 0.001) * 2.0 + t * (1.0 + i * 0.2);
        float line = fract(spiral * 1.5 + i * 0.5);
        
        float intensity = smoothstep(0.4, 0.5, line) * smoothstep(0.6, 0.5, line);
        float3 c = hsv2rgb(float3(fract(t * 0.05 + i * 0.2 + r * 0.5), 0.8, 1.0));
        
        color += c * intensity * (0.5 / (r + 0.1)) * exp(-r * 0.5);
    }
    
    // Core glow
    color += hsv2rgb(float3(fract(t * 0.2), 0.6, 1.0)) * (0.05 / (r + 0.001));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
