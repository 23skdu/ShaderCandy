#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Aurora Borealis - Northern Lights
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.2;
    
    // Night sky
    float3 sky = float3(0.02, 0.03, 0.08);
    
    // Stars
    float stars = pow(noise(p * 200.0), 20.0);
    sky += float3(1.0) * stars;
    
    // Aurora layers
    float3 aurora = float3(0.0);
    
    for (float i = 0.0; i < 4.0; i++) {
        float offset = i * 0.3;
        float speed = 1.0 + i * 0.2;
        
        // Curtain wave
        float wave = sin(p.x * 3.0 + t * speed + i) * 0.1;
        float wave2 = sin(p.x * 7.0 - t * speed * 0.7 + i * 2.0) * 0.05;
        
        // Vertical curtain effect
        float curtain = sin(p.x * 5.0 + t * 0.5 + i * 1.5) * 0.5 + 0.5;
        curtain *= sin(p.x * 2.0 - t * 0.3 + i) * 0.5 + 0.5;
        
        // Vertical fade
        float vertFade = smoothstep(-0.5, 0.5, p.y + wave + wave2);
        vertFade *= smoothstep(1.0, 0.3, p.y);
        
        // Horizontal variation
        float horizVar = sin(p.x * 10.0 + t + i * 3.0) * 0.5 + 0.5;
        
        // Combine
        float intensity = vertFade * curtain * horizVar;
        intensity *= smoothstep(1.5, 0.0, abs(p.x));
        
        // Aurora colors - green to purple gradient
        float hue = 0.3 + i * 0.15 + sin(t * 0.5 + i) * 0.1;
        float3 auroraColor = hsv2rgb(float3(hue, 0.8, 1.0));
        
        aurora += auroraColor * intensity * (0.4 - i * 0.08);
    }
    
    // Add glow
    aurora *= 1.5;
    
    // Combine sky and aurora
    float3 color = sky + aurora;
    
    // Ground silhouette
    if (p.y < -0.6) {
        color = float3(0.02, 0.04, 0.02);
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
