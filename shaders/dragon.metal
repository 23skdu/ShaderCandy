// Dragon 3D - Monster Eye
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    // Dragon scales distance field (approx)
    float2 suv = uv * 8.0;
    float2 id = floor(suv);
    float2 gv = fract(suv) - 0.5;
    
    float3 color = float3(0.05, 0.08, 0.05); // Base scale green
    
    // Scale shape
    float d = length(gv + 0.2 * sin(id.y + id.x + t));
    float scaleMask = smoothstep(0.4, 0.35, d);
    color = mix(color, float3(0.1, 0.2, 0.1), scaleMask);
    
    // The Eye
    float eyeD = length(uv);
    if(eyeD < 0.6) {
        float3 eyeCol = float3(0.8, 0.4, 0.0); // Orange iris
        // Pupil
        float pupil = smoothstep(0.1 + 0.05*sin(t), 0.02, abs(uv.x) + abs(uv.y * 0.3));
        eyeCol = mix(eyeCol, float3(0.0), pupil);
        
        // Iris details
        float mask = stepped_noise(float3(atan2(uv.y, uv.x)*5.0, eyeD * 20.0, t));
        eyeCol *= (0.8 + 0.4 * mask);
        
        // Specular highlight
        float spec = smoothstep(0.05, 0.0, length(uv - float2(0.2, 0.2)));
        eyeCol += float3(1.0) * spec;
        
        color = mix(color, eyeCol, smoothstep(0.6, 0.58, eyeD));
    }
    
    // Fire glow around eye
    color += float3(1.0, 0.3, 0.0) * (0.1 / (eyeD + 0.1)) * (0.8 + 0.2 * sin(t*5.0));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}