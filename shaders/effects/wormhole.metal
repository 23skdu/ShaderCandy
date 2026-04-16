#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Wormhole / Warp tunnel
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Center and polar coordinates
    float2 center = float2(0.0, 0.0);
    float2 delta = p - center;
    float r = length(delta);
    float angle = atan2(delta.y, delta.x);
    
    // Tunnel effect
    float tunnelDepth = 1.0 / (r + 0.1);
    
    // Animated spiral
    float spiral = sin(angle * 5.0 - t * 2.0 + r * 10.0);
    float spiral2 = sin(angle * 8.0 + t * 1.5 - r * 15.0);
    
    // Stars/lights rushing past
    float stars = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float speed = 1.0 + i * 0.5;
        float starField = pow(noise(float2(angle * 10.0, r * 5.0 - t * speed + i * 10.0)), 20.0);
        stars += starField * (1.0 - i * 0.3);
    }
    
    // Tunnel ring pattern
    float rings = sin(r * 30.0 - t * 5.0) * 0.5 + 0.5;
    rings = pow(rings, 4.0);
    
    // Colors - sci-fi blue/purple
    float3 tunnelColor = float3(0.2, 0.4, 0.8);
    float3 ringColor = float3(0.8, 0.3, 0.6);
    float3 starColor = float3(1.0, 0.95, 0.9);
    
    // Distance fade
    float fade = exp(-r * 2.0);
    
    // Combine
    float3 color = float3(0.02, 0.03, 0.08);
    color += tunnelColor * rings * 0.3;
    color += starColor * stars * fade;
    color += tunnelColor * spiral * 0.1 * fade;
    color += ringColor * spiral2 * 0.05 * fade;
    
    // Vignette
    color *= 1.0 - r * 0.5;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
