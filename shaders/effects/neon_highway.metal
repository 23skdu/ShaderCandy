#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;

    float t = fmod(uniforms.time * uniforms.speed, 3600.0);

    float2 p = centered;
    float3 color = float3(0.05, 0.0, 0.15);

    float skyGrad = smoothstep(-0.2, 0.6, p.y);
    color = mix(float3(0.2, 0.0, 0.3), float3(1.0, 0.4, 0.1), skyGrad);

    float2 sunPos = float2(0.0, 0.35);
    float sunDist = length(p - sunPos);
    float sun = smoothstep(0.22, 0.18, sunDist);
    float scan = step(0.5, fract(p.y * 12.0 + t * 0.5));
    color = mix(color, float3(1.0, 0.9, 0.3), sun * (0.7 + 0.3 * scan));

    float horizon = 0.0;
    if (p.y < horizon) {
        float depth = 1.0 / max(0.01, -(p.y + 0.05));
        float gx = p.x * depth;
        float gz = depth + t * (2.0 + uniforms.bass * 3.0) * uniforms.intensity;

        float gridX = smoothstep(0.02, 0.0, abs(fract(gx) - 0.5) - 0.48);
        float gridZ = smoothstep(0.02, 0.0, abs(fract(gz) - 0.5) - 0.48);
        float grid = max(gridX, gridZ);

        float3 floorCol = mix(float3(0.1, 0.0, 0.2), float3(0.9, 0.1, 0.6), grid);
        float fog = exp(-depth * 0.15);
        floorCol *= fog;
        color = mix(color, floorCol, smoothstep(0.0, -0.05, p.y));

        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float laneX = (fi - 1.5) * 0.25;
            float trailZ = fract(gz * 0.1 + fi * 0.25);
            float trail = smoothstep(0.05, 0.0, abs(p.x - laneX) - 0.01) *
                          smoothstep(0.0, 0.3, trailZ) * smoothstep(0.8, 0.3, trailZ);
            color += float3(1.0, 0.2, 0.8) * trail * fog * 0.8;
        }
    }

    color *= 1.0 - smoothstep(0.8, 1.6, length(p));

    return float4(color, uniforms.alpha);
}