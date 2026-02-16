#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Planet with atmosphere
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Planet position and size
    float2 planetCenter = float2(0.0, 0.0);
    float planetRadius = 0.6;
    
    // Distance to planet center
    float dist = length(p - planetCenter);
    
    // Planet surface
    float3 color = float3(0.0);
    
    if (dist < planetRadius) {
        // Surface coordinates
        float2 surfaceUV = (p - planetCenter) / planetRadius;
        
        // Rotate for animation
        float angle = t * 0.3;
        float cosA = cos(angle);
        float sinA = sin(angle);
        float2 rotated = float2(
            surfaceUV.x * cosA - surfaceUV.y * sinA,
            surfaceUV.x * sinA + surfaceUV.y * cosA
        );
        
        // Continents using noise
        float continents = fbm(float3(rotated * 3.0, 0.0), 5);
        continents = smoothstep(0.0, 0.5, continents);
        
        // Land/ocean colors
        float3 oceanColor = float3(0.1, 0.3, 0.5);
        float3 landColor = float3(0.2, 0.5, 0.2);
        float3 desertColor = float3(0.7, 0.6, 0.4);
        float3 iceColor = float3(0.95, 0.98, 1.0);
        
        // Mix based on latitude
        float latitude = abs(surfaceUV.y);
        float3 surfaceColor = mix(landColor, oceanColor, 1.0 - continents);
        
        // Add deserts in middle latitudes
        float desertZone = smoothstep(0.3, 0.5, latitude) * smoothstep(0.8, 0.6, latitude);
        surfaceColor = mix(surfaceColor, desertColor, desertZone * continents * 0.5);
        
        // Ice caps
        surfaceColor = mix(surfaceColor, iceColor, smoothstep(0.7, 0.95, latitude));
        
        // Add some cloud cover
        float clouds = fbm(float3(rotated * 5.0 + float2(t * 0.1, 0.0), 1.0), 4);
        clouds = smoothstep(0.4, 0.7, clouds);
        surfaceColor = mix(surfaceColor, float3(1.0), clouds * 0.5);
        
        // Lighting (sun from right)
        float2 lightDir = normalize(float2(1.0, 0.3));
        float2 normalDir = normalize(surfaceUV);
        float diffuse = max(0.0, dot(normalDir, lightDir));
        
        // Atmosphere on edge
        float atmosphere = smoothstep(planetRadius, planetRadius * 0.9, dist);
        float rimLight = smoothstep(planetRadius * 0.95, planetRadius, dist);
        
        // Apply lighting
        color = surfaceColor * (0.3 + diffuse * 0.7);
        
        // Add atmosphere glow
        float3 atmosColor = float3(0.3, 0.6, 1.0);
        color += atmosColor * rimLight * 0.8;
        color += atmosColor * (1.0 - atmosphere) * 0.3;
        
        // Edge darkening
        float edgeDark = smoothstep(planetRadius * 0.3, planetRadius, dist);
        color *= 0.5 + edgeDark * 0.5;
    }
    
    // Stars in background
    if (dist > planetRadius) {
        float stars = pow(noise(p * 200.0), 25.0);
        color += float3(0.8, 0.85, 1.0) * stars;
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
