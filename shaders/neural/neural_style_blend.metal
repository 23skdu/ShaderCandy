//
//  neural_style_blend.metal
//  ShaderCandy
//
//  Compute shader for blending neural style output with original
//

#include <metal_stdlib>
using namespace metal;

kernel void blendNeuralStyle(
    texture2d<float, access::sample> original [[texture(0)]],
    texture2d<float, access::sample> styled [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant float &strength [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
)
{
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float4 origColor = original.read(gid);
    float4 styledColor = styled.read(gid);

    // Blend based on strength
    float4 result = mix(origColor, styledColor, strength);

    output.write(result, gid);
}

// Fast style transfer preprocessing
kernel void preprocessForStyleTransfer(
    texture2d<float, access::sample> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant float2 &inputSize [[buffer(0)]],
    constant float2 &outputSize [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
)
{
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    // Calculate normalized coordinates
    float2 uv = float2(gid) / outputSize;

    // Sample from input with bilinear filtering
    float2 inputUV = uv * (inputSize / outputSize);

    constexpr sampler textureSampler(filter::linear, address::clamp_to_edge);
    float4 color = input.sample(textureSampler, inputUV);

    output.write(color, gid);
}

// Post-processing after style transfer
kernel void postprocessStyleTransfer(
    texture2d<float, access::sample> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant float &saturation [[buffer(0)]],
    constant float &contrast [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
)
{
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float4 color = input.read(gid);

    // Apply saturation adjustment
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb = mix(float3(luminance), color.rgb, saturation);

    // Apply contrast adjustment
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;

    output.write(color, gid);
}
