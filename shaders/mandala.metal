#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Mandala - sacred geometry
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.15;
    
    // Dark background
    float3 color = float3(0.02, 0.02, 0.04);
    
    // Polar coordinates
    float r = length(p);
    float angle = atan2(p.y, p.x);
    
    // Rotating mandala
    float angleRot = angle + t;
    
    // Multiple layers of petals
    for (float layer = 0.0; layer < 5.0; layer++) {
        float layerR = 0.1 + layer * 0.15;
        int numPetals = int(6.0 + layer * 4.0);
        float petalAngle = 6.28318 / float(numPetals);
        
        // Petal pattern
        float petalAngle2 = mod(angleRot, petalAngle) - petalAngle * 0.5;
        float petalShape = cos(petalAngle2 * float(numPetals) * 0.5);
        
        // Distance from ring
        float ringDist = abs(r - layerR);
        float ring = smoothstep(0.02, 0.0, ringDist);
        
        // Petal fill
        float petalDist = r - layerR;
        float petal = smoothstep(0.0, -0.08, petalDist) * smoothstep(0.12, 0.0, petalDist);
        petal *= smoothstep(petalAngle * 0.5, 0.0, abs(petalAngle2));
        
        // Colors - warm sacred colors
        float3 petalColor = hsv2rgb(float3(
            0.08 + layer * 0.05 + t * 0.02,  // Hue
            0.7,                              // Saturation
            0.8                              // Value
        ));
        
        color += petalColor * petal * 0.6;
        color += petalColor * ring * 0.4;
    }
    
    // Center circle
    float center = smoothstep(0.1, 0.08, r);
    color += float3(1.0, 0.9, 0.6) * center * 0.8;
    
    // Outer ring
    float outerRing = smoothstep(0.02, 0.0, abs(r - 0.75));
    color += float3(0.9, 0.7, 0.4) * outerRing;
    
    // Decorative dots
    for (float i = 0.0; i < 12.0; i++) {
        float dotAngle = i * 6.28318 / 12.0 + t;
        float dotR = 0.6;
        float2 dotPos = float2(cos(dotAngle), sin(dotAngle)) * dotR;
        
        float dot = smoothstep(0.03, 0.0, length(p - dotPos));
        color += float3(1.0, 0.8, 0.5) * dot * 0.7;
    }
    
    // Background glow
    color += float3(0.1, 0.05, 0.15) * (1.0 - r);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
