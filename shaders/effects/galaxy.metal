#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Spiral Galaxy
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Center of galaxy
    float2 center = float2(0.0, 0.0);
    float2 delta = p - center;
    float r = length(delta);
    float angle = atan2(delta.y, delta.x);
    
    // Galaxy parameters
    float spiralArms = 2.0;
    float spiralTightness = 3.0;
    float rotation = t * 0.2;
    
    // Spiral arm density
    float spiralAngle = angle + r * spiralTightness - rotation;
    float arms = sin(spiralArms * spiralAngle) * 0.5 + 0.5;
    arms = pow(arms, 2.0);
    
    // Core brightness
    float core = exp(-r * 4.0);
    float coreGlow = exp(-r * 2.0);
    
    // Disk density
    float disk = exp(-r * 1.5);

    float stars = pow(noise(p * 150.0), 25.0);
    float stars2 = pow(noise(p * 100.0 + 50.0), 20.0) * 0.7;
    
    // Dust lanes
    float dust = fbm(float3(p * 5.0, t * 0.05), 4);
    dust = smoothstep(0.3, 0.7, dust);
    
    // Colors
    float3 coreColor = float3(1.0, 0.95, 0.8);
    float3 armColor = float3(0.6, 0.7, 1.0);
    float3 dustColor = float3(0.3, 0.2, 0.4);
    float3 starColor = float3(1.0, 0.98, 0.95);
    
    // Combine
    float3 color = float3(0.02, 0.02, 0.05);
    
    // Core
    color += coreColor * core * 2.0;
    color += coreColor * coreGlow * 0.5;
    
    // Spiral arms
    color += armColor * arms * disk * 0.8;
    
    // Dust lanes
    color += dustColor * dust * disk * 0.3;
    
    // Stars
    color += starColor * (stars + stars2);
    
    // Add blue glow
    color += float3(0.3, 0.4, 0.8) * disk * 0.2;
    
    // Background stars
    float bgStars = pow(noise(p * 80.0), 30.0);
    color += float3(0.7, 0.75, 0.9) * bgStars * 0.3;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
