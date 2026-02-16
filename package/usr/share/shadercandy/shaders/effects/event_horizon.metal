#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  event_horizon.metal
//  ShaderCandy
//
//  Black hole singularity with gravitational lensing
//

using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Distort space (gravitational lensing)
    float r = length(uv);
    float distortion = 0.2 / (r + 0.01);
    float2 rayUV = uv * (1.0 + distortion);
    
    // Background Stars
    float3 color = float3(0.0);
    float stars = pow(noise(rayUV * 20.0), 15.0) * 2.0;
    color += stars * float3(0.8, 0.9, 1.0);
    
    // Accretion Disk
    float3 diskPos = float3(uv, 0.2);
    diskPos = rotateX(diskPos, 1.2);
    diskPos = rotateY(diskPos, t * 0.1);
    
    float angle = atan2(diskPos.z, diskPos.x);
    float dist = length(diskPos.xz);
    
    if (dist > 0.4 && dist < 1.5) {
        float f = fbm(float3(dist * 5.0, angle * 2.0, t), 4);
        float density = smoothstep(1.5, 0.6, dist) * smoothstep(0.3, 0.6, dist);
        float3 diskColor = mix(float3(1.0, 0.4, 0.1), float3(1.0, 0.8, 0.5), f);
        color += diskColor * density * (0.5 + 0.5 * f);
    }
    
    // The Singularity (Event Horizon)
    float horizon = smoothstep(0.35, 0.34, r);
    color *= (1.0 - horizon);
    
    // Photon Ring
    float ring = exp(-abs(r - 0.36) * 50.0);
    color += float3(1.0, 0.9, 0.8) * ring;
    
    // Bloom/Glow
    float glow = exp(-r * 2.0);
    color += float3(0.2, 0.1, 0.4) * glow * 0.5;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
