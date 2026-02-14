// Unicorn - Horn glow and magical aura effects

#include <metal_stdlib>
using namespace metal;

/* struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float speed;
    float intensity;
    float magic;
    float aura;
    float sparkle;
}; */



float3 magicalAura(float2 uv, float time) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float aura = sin(p.y * 8.0 + time * 2.0) * 0.5 + 0.5;
    aura = smoothstep(0.4, 0.6, aura);
    
    float3 auraColor = float3(1.0, 0.8, 1.0);
    auraColor = mix(auraColor, float3(1.0, 0.9, 1.0), aura);
    
    float auraNoise = custom_noise(p * 5.0 + time * 1.0);
    auraColor *= auraNoise * 0.5 + 0.5;
    
    return auraColor * aura;
}

float3 hornGlow(float2 uv, float time) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float2 hornPos = float2(-0.4, 0.3);
    float hornDist = length(p - hornPos);
    
    float horn = smoothstep(0.08, 0.07, hornDist);
    
    float3 hornColor = float3(1.0, 0.8, 1.0);
    
    float hornGlow = sin(time * 10.0 + hornDist * 20.0) * 0.5 + 0.5;
    hornGlow = smoothstep(0.4, 0.6, hornGlow);
    
    hornColor *= hornGlow;
    
    return hornColor * horn;
}

float3 sparkles(float2 uv, float time) {
    float2 p = (uv - 0.5) * 2.0;
    p.x *= 1.5;
    
    float sparkle = custom_noise(p * 20.0 + time * 5.0);
    sparkle = step(0.85, sparkle);
    
    float3 sparkleColor = float3(1.0, 1.0, 1.0);
    sparkleColor *= sparkle;
    
    return sparkleColor * sparkle;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                                  constant Uniforms& u [[buffer(0)]]) {
    // Injected default values for missing uniforms
    float u_magic = 1.0;
    float u_aura = 1.0;
    float u_sparkle = 1.0;

    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * u.speed * 0.3;
    
    // Unicorn body gradient
    float3 bodyColor = float3(0.9, 0.9, 1.0);
    float bodyGradient = length(p);
    bodyGradient = smoothstep(0.0, 0.8, bodyGradient);
    bodyColor = mix(bodyColor, float3(1.0, 1.0, 1.0), bodyGradient);
    
    // Magical aura
    float3 aura = magicalAura(uv, t * u_magic);
    bodyColor += aura * 0.6;
    
    // Horn glow
    float3 horn = hornGlow(uv, t * u_aura);
    bodyColor += horn * 0.8;
    
    // Sparkles
    float3 sparklesCol = sparkles(uv, t * u_sparkle);
    bodyColor += sparklesCol * 0.3;
    
    // Unicorn eye
    float2 eyePos1 = float2(-0.3, 0.2);
    float2 eyePos2 = float2(0.3, 0.2);
    
    float eyeDist1 = length(p - eyePos1);
    float eyeDist2 = length(p - eyePos2);
    
    float eye1 = smoothstep(0.08, 0.07, eyeDist1);
    float eye2 = smoothstep(0.08, 0.07, eyeDist2);
    
    float3 eyeColor = float3(0.8, 0.8, 1.0);
    
    float eyeGlow1 = sin(t * 5.0 + eyeDist1 * 20.0) * 0.5 + 0.5;
    float eyeGlow2 = sin(t * 5.0 + eyeDist2 * 20.0) * 0.5 + 0.5;
    
    eyeGlow1 = smoothstep(0.4, 0.6, eyeGlow1);
    eyeGlow2 = smoothstep(0.4, 0.6, eyeGlow2);
    
    eyeColor *= (eyeGlow1 + eyeGlow2) * 0.5;
    
    bodyColor += eyeColor * (eye1 + eye2) * 0.6;
    
    // Intensity effects
    bodyColor *= u.intensity * 0.8 + 0.2;
    
    return float4(bodyColor, 1.0);
}