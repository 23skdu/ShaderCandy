#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Ocean waves with foam and reflections
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.3;
    
    // Ocean layers
    float wave1 = sin(p.x * 3.0 + t * 1.5) * 0.15;
    float wave2 = sin(p.x * 7.0 - t * 2.0) * 0.08;
    float wave3 = sin(p.x * 15.0 + t * 3.0) * 0.03;
    float waves = wave1 + wave2 + wave3;
    
    // Distance from water surface
    float waterLevel = 0.0;
    float dist = p.y - waterLevel - waves;
    
    // Sky gradient
    float3 skyTop = float3(0.05, 0.1, 0.2);
    float3 skyBottom = float3(0.3, 0.4, 0.6);
    float3 sky = mix(skyBottom, skyTop, uv.y);
    
    // Water colors
    float3 deepWater = float3(0.02, 0.08, 0.15);
    float3 shallowWater = float3(0.1, 0.3, 0.4);
    float3 foam = float3(0.9, 0.95, 1.0);
    
    // Fresnel reflection
    float fresnel = pow(1.0 - abs(p.y), 3.0);
    
    // Water surface
    float waterDepth = smoothstep(-0.5, 0.1, dist);
    float3 waterColor = mix(deepWater, shallowWater, waterDepth);
    
    // Foam on wave peaks
    float foamAmount = smoothstep(0.05, 0.15, dist + waves * 0.5);
    foamAmount *= smoothstep(0.0, 0.2, uv.y);
    waterColor = mix(waterColor, foam, foamAmount * 0.6);
    
    // Reflection of sky
    float reflectionY = 1.0 - uv.y;
    float3 reflection = mix(skyBottom, skyTop, reflectionY);
    waterColor = mix(waterColor, reflection, fresnel * 0.5);
    
    // Sun reflection
    float2 sunPos = float2(0.3, 0.7);
    float sunReflect = smoothstep(0.1, 0.0, length(p - sunPos + float2(0.0, waves)));
    waterColor += float3(1.0, 0.9, 0.7) * sunReflect * 0.8;
    
    // Combine
    float3 color = mix(sky, waterColor, smoothstep(0.3, 0.5, uv.y));
    color *= uniforms.intensity;
    
    return float4(color, uniforms.alpha);
}
