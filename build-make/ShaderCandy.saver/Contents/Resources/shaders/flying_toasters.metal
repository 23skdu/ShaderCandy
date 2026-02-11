// Flying Toasters on Fire!
// Mimics the classic screensaver but with realistic burning toasters.

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]],
                             texture2d<float> toasterTexture [[texture(0)]],
                             sampler toasterSampler [[sampler(0)]]) {
    float2 uv = in.texCoord;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 scaledUV = uv;
    scaledUV.x *= aspect;
    
    float t = uniforms.time * 0.5;
    float3 finalColor = float3(0.02, 0.01, 0.05); // Dark deep purple space
    
    // Starfield background
    float2 starUV = uv * 5.0;
    float starPhase = sin(starUV.x * 13.0 + starUV.y * 17.0 + t);
    if (starPhase > 0.98) {
        finalColor += float3(0.8, 0.8, 1.0) * pow((starPhase - 0.98) / 0.02, 2.0);
    }

    // Flying Toasters Logic
    // Grid-based sprites
    float gridSize = 0.4;
    for (float i = -2.0; i < 3.0; i++) {
        for (float j = -2.0; j < 3.0; j++) {
            // Unique seed for each sprite in the virtual grid
            float2 seed = float2(i, j);
            float randOffset = fract(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
            
            // Movement: diagonally from top-right to bottom-left
            float speed = 0.3 + randOffset * 0.2;
            float timeOffset = randOffset * 10.0;
            float progress = fract((uniforms.time + timeOffset) * speed);
            
            // Start and end positions
            float2 startPos = float2(aspect + 0.5, 1.5);
            float2 endPos = float2(-0.5, -0.5);
            float2 spritePos = mix(startPos, endPos, progress);
            
            // Sprite box
            float spriteScale = 0.2 + randOffset * 0.1;
            float2 spriteUV = (scaledUV - spritePos) / spriteScale + 0.5;
            
            // Check if inside sprite bounds
            if (spriteUV.x >= 0.0 && spriteUV.x <= 1.0 && spriteUV.y >= 0.0 && spriteUV.y <= 1.0) {
                // Flip texture if needed or just sample
                float4 texColor = toasterTexture.sample(toasterSampler, spriteUV);
                
                // Classic Flying Toasters were often black-background sprites
                // Our generated image is on black, so use color intensity or alpha if present
                float alpha = texColor.a;
                // If alpha is 0 (often true for PNG without alpha from some generators), 
                // use luma as mask since it's on black
                if (alpha < 0.01) {
                    alpha = smoothstep(0.01, 0.1, length(texColor.rgb));
                }
                
                // Add sprite color
                finalColor = mix(finalColor, texColor.rgb, alpha);
                
                // Add some extra heat glow
                finalColor += float3(0.5, 0.1, 0.0) * alpha * (sin(t * 10.0 + randOffset * 6.28) * 0.2 + 0.8);
            }
        }
    }
    
    return float4(finalColor, uniforms.alpha);
}
