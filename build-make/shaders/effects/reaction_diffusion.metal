// Reaction-Diffusion (Gray-Scott model)
// fragment_sim: Updates chemical concentrations
// fragment_main: Maps concentrations to visual output

// Simulation Pass
fragment float4 fragment_sim(VertexOut in [[stage_in]],
                            constant Uniforms &uniforms [[buffer(0)]],
                            texture2d<float> prevTexture [[texture(0)]],
                            sampler s [[sampler(0)]]) {
    float2 uv = in.texCoord;
    float2 texel = 1.0 / float2(prevTexture.get_width(), prevTexture.get_height());
    
    // Sample current state (r=U, g=V)
    float4 center = prevTexture.sample(s, uv);
    
    // Initialize if center is null/clear (first frame) (Branchless Seed)
    float d = length(uv - 0.5);
    float4 seedCol = mix(float4(1.0, 0.0, 0.0, 1.0), float4(1.0, 0.5, 0.0, 1.0), step(d, 0.02));
    if (uniforms.frame < 10) return seedCol;
    
    float2 state = center.rg;
    
    // Laplacian (9-point stencil)
    float2 laplacian = 
        prevTexture.sample(s, uv + float2(texel.x, 0)).rg * 0.2 +
        prevTexture.sample(s, uv - float2(texel.x, 0)).rg * 0.2 +
        prevTexture.sample(s, uv + float2(0, texel.y)).rg * 0.2 +
        prevTexture.sample(s, uv - float2(0, texel.y)).rg * 0.2 +
        prevTexture.sample(s, uv + float2(texel.x, texel.y)).rg * 0.05 +
        prevTexture.sample(s, uv + float2(-texel.x, texel.y)).rg * 0.05 +
        prevTexture.sample(s, uv + float2(texel.x, -texel.y)).rg * 0.05 +
        prevTexture.sample(s, uv + float2(-texel.x, -texel.y)).rg * 0.05 -
        state;

    // Gray-Scott parameters
    // Dynamic params based on mouse or time
    float feed = 0.0545 + sin(uniforms.time * 0.1) * 0.01;
    float kill = 0.062 + cos(uniforms.time * 0.08) * 0.005;
    float du = 1.0;
    float dv = 0.5;
    
    float reaction = state.x * state.y * state.y;
    float nextU = state.x + (du * laplacian.x - reaction + feed * (1.0 - state.x)) * uniforms.speed;
    float nextV = state.y + (dv * laplacian.y + reaction - (feed + kill) * state.y) * uniforms.speed;
    
    return float4(clamp(nextU, 0.0, 1.0), clamp(nextV, 0.0, 1.0), 0.0, 1.0);
}

// Render Pass
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]],
                             texture2d<float> stateTexture [[texture(1)]],
                             sampler s [[sampler(0)]]) {
    float2 state = stateTexture.sample(s, in.texCoord).rg;
    
    // Color mapping based on chemical concentration V
    float v = state.y;
    float3 col = float3(0.0);
    
    // Psychedelic color mapping
    col = float3(
        0.5 + 0.5 * sin(v * 10.0 + uniforms.time),
        0.5 + 0.5 * sin(v * 20.0 + uniforms.time * 1.2),
        0.5 + 0.5 * sin(v * 30.0 + uniforms.time * 0.8)
    ) * uniforms.intensity;
    
    // Mask with concentration
    col *= smoothstep(0.01, 0.1, v);
    
    // Background glow
    col += float3(0.1, 0.05, 0.2) * state.x * uniforms.intensity;
    
    return float4(col, uniforms.alpha);
}
