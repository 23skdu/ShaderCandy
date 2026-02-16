#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Black Hole with gravitational lensing
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Black hole position
    float2 bhPos = float2(0.0, 0.0);
    float bhRadius = 0.15;
    float eventHorizon = 0.2;
    
    float2 delta = p - bhPos;
    float r = length(delta);
    float angle = atan2(delta.y, delta.x);
    
    // Gravitational lensing distortion
    float distortion = 1.0 / (r + 0.1);
    distortion = pow(distortion, 0.5);
    
    // Lensed position
    float2 lensedP = p + normalize(delta) * distortion * 0.1;
    
    // Accretion disk
    float diskInner = 0.25;
    float diskOuter = 0.8;
    float disk = smoothstep(diskInner, diskInner + 0.1, r) * smoothstep(diskOuter, diskOuter - 0.3, r);
    
    // Rotate disk
    float diskAngle = angle + t * 0.5 + r * 5.0;
    float diskPattern = sin(diskAngle * 8.0) * 0.5 + 0.5;
    diskPattern += sin(diskAngle * 12.0 + t) * 0.3;
    
    // Doppler beaming (brighter on approaching side)
    float doppler = sin(angle + t * 0.5) * 0.5 + 0.5;
    doppler = pow(doppler, 0.5);
    
    disk *= diskPattern * doppler;
    
    // Accretion disk colors (hot plasma)
    float3 diskColorInner = float3(1.0, 0.9, 0.7);
    float3 diskColorOuter = float3(0.8, 0.3, 0.1);
    float3 diskColor = mix(diskColorOuter, diskColorInner, smoothstep(diskOuter, diskInner, r));
    
    // Black hole (event horizon)
    float blackHole = smoothstep(bhRadius + 0.02, bhRadius, r);
    
    // Photon sphere glow
    float photonSphere = smoothstep(bhRadius + 0.08, bhRadius + 0.02, r);
    photonSphere *= smoothstep(bhRadius - 0.02, bhRadius + 0.02, r);
    
    // Background stars (lensed)
    float3 bgColor = float3(0.02, 0.02, 0.04);
    float stars = pow(noise(lensedP * 200.0), 25.0);
    bgColor += float3(1.0, 0.98, 0.95) * stars;
    
    // Nebula background
    float nebula = fbm(float3(lensedP * 3.0, t * 0.1), 4);
    bgColor += float3(0.2, 0.1, 0.3) * nebula * 0.3;
    
    // Combine
    float3 color = bgColor;
    
    // Add accretion disk
    color = mix(color, diskColor, disk * 0.9);
    
    // Add photon sphere glow
    color += float3(1.0, 0.8, 0.5) * photonSphere * 0.8;
    
    // Black hole
    color *= (1.0 - blackHole);
    
    // Inner glow
    color += float3(1.0, 0.6, 0.2) * smoothstep(bhRadius + 0.15, bhRadius, r) * 0.3;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
