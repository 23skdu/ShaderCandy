#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Procedural forest with trees and atmosphere
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.15;
    
    // Sky gradient - dawn/dusk
    float3 skyTop = float3(0.15, 0.25, 0.45);
    float3 skyBottom = float3(0.9, 0.6, 0.3);
    float3 sky = mix(skyBottom, skyTop, uv.y);
    
    // Sun
    float2 sunPos = float2(0.7, 0.75);
    float sunDist = length(p - sunPos);
    float sun = smoothstep(0.15, 0.0, sunDist);
    sky += float3(1.0, 0.8, 0.4) * sun;
    
    // Distant mountains
    float mountain1 = sin(p.x * 2.0 + 1.0) * 0.15 + sin(p.x * 5.0) * 0.05 - 0.3;
    float mountain2 = sin(p.x * 3.0 - 0.5) * 0.1 + 0.1;
    
    // Ground
    float ground = -0.4 + sin(p.x * 20.0) * 0.02;
    
    // Trees - procedural using noise
    float3 color = sky;
    
    // Far mountains
    if (p.y < mountain1 + 0.1) {
        float3 mtColor = float3(0.2, 0.3, 0.35);
        mtColor = mix(mtColor, skyBottom, smoothstep(mountain1, mountain1 + 0.2, p.y));
        color = mtColor;
    }
    
    // Mid-ground trees
    for (float i = -3.0; i < 3.0; i += 0.15) {
        float treeX = i + sin(i * 7.0) * 0.1;
        float treeHeight = 0.2 + noise(float2(i * 10.0, 0.0)) * 0.3;
        float treeWidth = 0.02 + noise(float2(i * 20.0, 1.0)) * 0.01;
        
        // Tree trunk
        if (abs(p.x - treeX) < treeWidth && p.y < ground + treeHeight && p.y > ground) {
            color = float3(0.15, 0.1, 0.05);
        }
        
        // Tree canopy (triangle shape)
        float canopyHeight = treeHeight * (1.0 - (p.y - ground) / treeHeight);
        if (abs(p.x - treeX) < canopyHeight * 0.4 && p.y > ground && p.y < ground + treeHeight * 0.8) {
            float shade = (p.y - ground) / (treeHeight * 0.8);
            color = mix(float3(0.05, 0.15, 0.05), float3(0.1, 0.3, 0.1), shade);
        }
    }
    
    // Ground plane
    if (p.y < ground) {
        float3 grassColor = float3(0.1, 0.25, 0.1);
        float grassNoise = noise(p * 50.0 + t * 0.5);
        color = mix(grassColor, float3(0.15, 0.35, 0.12), grassNoise * 0.5);
    }
    
    // Fog/atmosphere
    float fogAmount = smoothstep(0.5, -0.5, p.y);
    color = mix(color, skyBottom * 0.8, fogAmount * 0.4);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
