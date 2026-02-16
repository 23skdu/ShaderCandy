#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Fluid Dynamics - Real-time fluid simulation

// Fluid velocity field
float2 fluidVelocity(float2 uv, float t, float turbulence) {
    float2 v = float2(0.0);
    
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float scale = pow(2.0, fi);
        
        v += float2(
            snoise(float3(uv * scale, t * 0.1 * turbulence + fi)),
            snoise(float3(uv * scale + 100.0, t * 0.1 * turbulence + fi))
        ) / scale;
    }
    
    return v * turbulence;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float viscosity = 0.01;
    float turbulence = 1.0;
    float colorShift = 0.5;
    int palette = 0;
    
    float time = t * (1.0 - viscosity * 10.0);
    
    float2 vel = fluidVelocity(uv, time, turbulence);
    
    float2 advectedUV = uv - vel * viscosity;
    
    float curl = snoise(float3(advectedUV * 3.0, time)) * 
                 snoise(float3(advectedUV * 5.0 + 50.0, time * 0.5));
    
    float intensity = length(vel) * 0.5 + abs(curl) * 0.5;
    intensity = clamp(intensity, 0.0, 1.0);
    
    float hue = intensity + colorShift * time * 0.1;
    hue = fract(hue);
    
    // Ocean palette
    float3 color = mix(
        float3(0.0, 0.1, 0.3),
        float3(0.0, 0.8, 1.0),
        smoothstep(0.0, 1.0, hue)
    );
    
    float detail = snoise(float3(uv * 20.0, time * 2.0));
    color *= 0.9 + detail * 0.1 * turbulence;
    
    color *= 1.0 - length(p) * 0.3;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
