#include "ShaderInterop.h"

// Threshold kernel - isolates bright spots
fragment float4 bloom_threshold(VertexOut in [[stage_in]],
                               texture2d<float> sceneTexture [[texture(0)]],
                               sampler s [[sampler(0)]]) {
    float4 color = sceneTexture.sample(s, in.texCoord);
    float brightness = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    if (brightness > 0.8) {
        return color;
    }
    return float4(0.0, 0.0, 0.0, 1.0);
}

// Blur kernel - Horizontal
fragment float4 bloom_blur_h(VertexOut in [[stage_in]],
                            texture2d<float> inputTexture [[texture(0)]],
                            sampler s [[sampler(0)]]) {
    float2 texel = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    float4 color = 0.0;
    float weight[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    
    color += inputTexture.sample(s, in.texCoord) * weight[0];
    for(int i = 1; i < 5; i++) {
        color += inputTexture.sample(s, in.texCoord + float2(texel.x * i, 0.0)) * weight[i];
        color += inputTexture.sample(s, in.texCoord - float2(texel.x * i, 0.0)) * weight[i];
    }
    return color;
}

// Blur kernel - Vertical
fragment float4 bloom_blur_v(VertexOut in [[stage_in]],
                            texture2d<float> inputTexture [[texture(0)]],
                            sampler s [[sampler(0)]]) {
    float2 texel = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());
    float4 color = 0.0;
    float weight[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    
    color += inputTexture.sample(s, in.texCoord) * weight[0];
    for(int i = 1; i < 5; i++) {
        color += inputTexture.sample(s, in.texCoord + float2(0.0, texel.y * i)) * weight[i];
        color += inputTexture.sample(s, in.texCoord - float2(0.0, texel.y * i)) * weight[i];
    }
    return color;
}

// Combine kernel
fragment float4 bloom_combine(VertexOut in [[stage_in]],
                             texture2d<float> sceneTexture [[texture(0)]],
                             texture2d<float> bloomTexture [[texture(1)]],
                             sampler s [[sampler(0)]]) {
    float4 sceneColor = sceneTexture.sample(s, in.texCoord);
    float4 bloomColor = bloomTexture.sample(s, in.texCoord);
    return sceneColor + bloomColor * 0.5; // Additive blend with intensity control
}
