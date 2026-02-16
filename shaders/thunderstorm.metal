#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Thunderstorm
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Stormy sky gradient
    float3 skyTop = float3(0.02, 0.03, 0.06);
    float3 skyBottom = float3(0.15, 0.18, 0.25);
    float3 color = mix(skyBottom, skyTop, uv.y);
    
    // Animated clouds
    float clouds = 0.0;
    for (float i = 0.0; i < 5.0; i++) {
        float scale = 1.0 + i * 0.5;
        float speed = 0.3 + i * 0.1;
        float cloudNoise = fbm(float3(p.xy * scale, t * speed * 0.1), 4);
        clouds += cloudNoise * (0.5 - i * 0.08);
    }
    clouds = smoothstep(0.2, 0.7, clouds);
    
    float3 cloudColor = float3(0.2, 0.22, 0.28);
    color = mix(color, cloudColor, clouds * 0.8);
    
    // Lightning flash (occasional)
    float lightning = 0.0;
    float flashTime = floor(t * 0.5);
    float flashRand = hash(flashTime);
    if (flashRand > 0.85) {
        float flashDur = fract(t * 0.5);
        if (flashDur < 0.1) {
            lightning = 1.0 - flashDur * 10.0;
            lightning = pow(lightning, 2.0);
        }
    }
    
    // Add lightning illumination
    color += float3(0.9, 0.92, 1.0) * lightning * 0.6;
    
    // Lightning bolt
    if (lightning > 0.1) {
        float boltX = -0.2 + sin(p.y * 15.0 + t * 10.0) * 0.1;
        float bolt = smoothstep(0.03, 0.0, abs(p.x - boltX));
        bolt *= smoothstep(-0.8, -0.5, p.y);
        bolt *= smoothstep(0.8, 0.3, p.y);
        
        // Branch
        float branch1 = smoothstep(0.02, 0.0, abs(p.x - boltX - 0.1 * (p.y + 0.3)));
        branch1 *= step(-0.3, p.y) * step(p.y, 0.0);
        
        color += float3(1.0, 1.0, 0.95) * (bolt + branch1 * 0.5) * lightning;
    }
    
    // Rain
    float rain = 0.0;
    for (float i = 0.0; i < 40.0; i++) {
        float seed = i * 0.17;
        float2 dropPos = float2(
            hash(seed) * 2.0 - 1.0,
            mod(hash(seed + 50.0) + t * (0.8 + hash(seed) * 0.5), 2.5) - 1.2
        );
        
        float dx = abs(p.x - dropPos.x);
        float drop = smoothstep(0.008, 0.0, dx);
        drop *= smoothstep(0.15, 0.0, (p.y - dropPos.y));
        
        rain += drop * 0.15;
    }
    
    color += float3(0.6, 0.65, 0.75) * rain;
    
    // Ground
    if (p.y < -0.7) {
        color = float3(0.05, 0.06, 0.08);
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
