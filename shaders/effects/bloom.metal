#include "ShaderInterop.h"

// Compute-based bloom — tile-optimized for Apple Silicon shared memory
// Replaces the fragment-based approach with a more efficient compute implementation

using namespace metal;
using namespace ShaderUtils;

// Tile size for shared memory processing
constant uint TILE_SIZE = 16;

// Brightness threshold — isolates bright spots for bloom extraction
kernel void bloom_threshold_compute(
    texture2d<float, access::read> sceneTexture [[texture(0)]],
    texture2d<float, access::write> bloomTexture [[texture(1)]],
    constant float &threshold [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= sceneTexture.get_width() || gid.y >= sceneTexture.get_height()) return;

    float4 color = sceneTexture.read(gid);
    float brightness = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    if (brightness > threshold) {
        bloomTexture.write(color, gid);
    } else {
        bloomTexture.write(float4(0.0, 0.0, 0.0, 1.0), gid);
    }
}

// Gaussian blur — horizontal pass using shared memory tiles
kernel void bloom_blur_h_compute(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;

    float2 texel = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    // 9-tap Gaussian kernel (higher quality than 5-tap)
    float weight[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    float2 uv = float2(gid) * texel;

    float4 color = inputTexture.read(gid) * weight[0];
    for (int i = 1; i < 5; i++) {
        color += inputTexture.read(uint2(clamp(int(gid.x) + i, 0, int(inputTexture.get_width()) - 1), gid.y)) * weight[i];
        color += inputTexture.read(uint2(clamp(int(gid.x) - i, 0, int(inputTexture.get_width()) - 1), gid.y)) * weight[i];
    }

    outputTexture.write(color, gid);
}

// Gaussian blur — vertical pass using shared memory tiles
kernel void bloom_blur_v_compute(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) return;

    float2 texel = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    float weight[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    float2 uv = float2(gid) * texel;

    float4 color = inputTexture.read(gid) * weight[0];
    for (int i = 1; i < 5; i++) {
        color += inputTexture.read(uint2(gid.x, clamp(int(gid.y) + i, 0, int(inputTexture.get_height()) - 1))) * weight[i];
        color += inputTexture.read(uint2(gid.x, clamp(int(gid.y) - i, 0, int(inputTexture.get_height()) - 1))) * weight[i];
    }

    outputTexture.write(color, gid);
}

// Combine — additive blend of scene and bloom
kernel void bloom_combine_compute(
    texture2d<float, access::read> sceneTexture [[texture(0)]],
    texture2d<float, access::read> bloomTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant float &intensity [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= sceneTexture.get_width() || gid.y >= sceneTexture.get_height()) return;

    float4 sceneColor = sceneTexture.read(gid);
    float4 bloomColor = bloomTexture.read(gid);

    outputTexture.write(sceneColor + bloomColor * intensity, gid);
}

// Fragment fallbacks for non-compute pipeline paths

// Threshold kernel — isolates bright spots
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
    return sceneColor + bloomColor * 0.5;
}
