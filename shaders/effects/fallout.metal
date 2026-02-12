//
//  fallout.metal
//  ShaderCandy
//
//  Nuclear blast and mushroom cloud effect
//

#include <metal_stdlib>
#include "base/common.metal"
#include "base/utils.metal"

using namespace metal;

// Noise functions for procedural effects
#include "base/noise.metal"

struct FragmentUniforms {
    float time;
    float speed;
    float2 resolution;
    float2 mouse;
    float mouseButtons;
    float intensity;
    float4 date;
    int32_t frame;
    float deltaTime;
    float alpha;
    float gravity;
    
    // Audio reactivity
    float volume;
    float bass;
    float mid;
    float treble;
    float beat;
    float audioData[256];
};

// Mushroom cloud SDF
float mushroomCloudSDF(float3 p, float time) {
    // Stem (lower part)
    float stemHeight = 0.3 + 0.2 * sin(time * 0.5);
    float stemWidth = 0.15 + 0.05 * sin(time * 0.3);
    float stem = length(p.xz) - stemWidth;
    stem = max(stem, abs(p.y + 0.5) - stemHeight);
    
    // Cap (mushroom head)
    float capHeight = 0.5 + 0.1 * sin(time * 0.2);
    float capWidth = 0.6 + 0.2 * sin(time * 0.4);
    float cap = length(p.xz) - capWidth;
    cap = max(cap, abs(p.y + stemHeight + 0.25) - capHeight);
    
    // Smooth union
    float k = 0.1;
    float h = clamp(0.5 + 0.5 * (stem - cap) / k, 0.0, 1.0);
    return mix(stem, cap, h) - k * h * (1.0 - h);
}

// Fireball SDF
float fireballSDF(float3 p, float time) {
    float3 center = float3(0.0, -0.2, 0.0);
    float radius = 0.25 + 0.1 * sin(time * 2.0);
    float sphere = length(p - center) - radius;
    
    // Add turbulence
    float noise = fbm(p * 5.0 + time * 2.0) * 0.1;
    return sphere + noise;
}

// Smoke accumulation
float smokeDensity(float3 p, float time) {
    float rise = p.y + 0.5 - time * 0.3;
    float spread = length(p.xz) * (1.0 + rise * 2.0);
    float base = max(0.0, 0.4 - spread);
    
    // Add billowy noise
    float noise = fbm(p * 3.0 + float3(0.0, time * 0.5, time * 0.3));
    
    return base * (0.5 + 0.5 * noise) * max(0.0, 1.0 - rise);
}

// Nuclear flash
float flashIntensity(float time, float audio) {
    float flash = 0.0;
    float flashStart = 0.0;  // Initial blast
    
    if (time > flashStart && time < flashStart + 0.5) {
        float t = (time - flashStart) / 0.5;
        flash = sin(t * M_PI_F) * (1.0 + audio * 2.0);
    }
    
    // Secondary flashes
    for (int i = 1; i <= 3; i++) {
        float flashTime = flashStart + 0.5 + float(i) * 0.3;
        if (time > flashTime && time < flashTime + 0.2) {
            float t = (time - flashTime) / 0.2;
            flash += sin(t * M_PI_F) * 0.3;
        }
    }
    
    return flash;
}

// Procedural color palette
float3 nuclearPalette(float t, float intensity) {
    // Fire colors: white -> yellow -> orange -> red -> dark
    float3 white = float3(1.0, 1.0, 1.0);
    float3 yellow = float3(1.0, 0.9, 0.2);
    float3 orange = float3(1.0, 0.5, 0.1);
    float3 red = float3(0.9, 0.1, 0.0);
    float3 darkRed = float3(0.4, 0.0, 0.0);
    float3 smoke = float3(0.1, 0.1, 0.1);
    
    if (t < 0.2) return mix(smoke, darkRed, t * 5.0);
    if (t < 0.4) return mix(darkRed, red, (t - 0.2) * 5.0);
    if (t < 0.6) return mix(red, orange, (t - 0.4) * 5.0);
    if (t < 0.8) return mix(orange, yellow, (t - 0.6) * 5.0);
    return mix(yellow, white, (t - 0.8) * 5.0);
}

// Ground glow
float groundGlow(float2 uv, float time) {
    float dist = length(uv - float2(0.5, 0.3));
    float glow = exp(-dist * 3.0) * (0.5 + 0.5 * sin(time * 2.0));
    return glow;
}

// Main fragment shader
fragment float4 falloutFragment(
    VertexOut in [[stage_in]],
    constant FragmentUniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    
    // Adjust UV for aspect ratio
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 centeredUV = uv - float2(0.5, 0.3);
    centeredUV.x *= aspect;
    
    float time = uniforms.time * uniforms.speed;
    float intensity = uniforms.intensity;
    float audio = uniforms.bass * 2.0 + uniforms.mid;
    
    float3 color = float3(0.0);
    
    // Background - dark sky with subtle gradient
    float skyGradient = 1.0 - uv.y;
    float3 skyColor = mix(float3(0.05, 0.05, 0.08), float3(0.1, 0.05, 0.05), skyGradient);
    color = skyColor;
    
    // Ground plane
    float groundUV = uv.y;
    if (uv.y < 0.35) {
        // Scorched earth effect
        float noise = fbm(float3(uv * 10.0, time * 0.1));
        float3 groundColor = mix(float3(0.1, 0.08, 0.05), float3(0.15, 0.1, 0.08), noise);
        float groundDist = 0.35 - uv.y;
        float groundFade = smoothstep(0.0, 0.1, groundDist);
        color = mix(groundColor * 0.3, color, groundFade);
    }
    
    // Fireball at center
    float3 fireballPos = float3(0.0, -0.1, 0.0);
    float3 toFireball = float3(centeredUV, -1.0);
    float fireballDist = length(toFireball);
    float fireballRadius = 0.15 + 0.05 * sin(time * 3.0) * intensity;
    
    if (fireballDist < fireballRadius * 2.0) {
        float fireballNoise = fbm(float3(centeredUV * 8.0, time * 3.0));
        float fireballCore = smoothstep(fireballRadius * 2.0, 0.0, fireballDist);
        float fireballEdge = smoothstep(fireballRadius, 0.0, fireballDist - fireballRadius);
        float fireballIntensity = fireballCore * (0.8 + 0.2 * fireballNoise);
        
        // Fireball color gradient
        float3 fireballColor = nuclearPalette(length(centeredUV) / fireballRadius, 1.0 - fireballCore);
        color = mix(color, fireballColor * (2.0 + audio), fireballEdge * fireballIntensity);
    }
    
    // Rising mushroom cloud
    float cloudTime = mod(time * 0.5, 5.0);  // Loop every 5 seconds
    float cloudBase = -0.2 + cloudTime * 0.15;
    
    if (cloudBase < 0.5) {
        float3 cloudPos = float3(centeredUV.x, uv.y - 0.5 + cloudBase, 0.0);
        
        // Multiple cloud layers for depth
        for (int i = 0; i < 3; i++) {
            float layerOffset = float(i) * 0.15;
            float3 layerPos = cloudPos - float3(0.0, layerOffset, 0.0);
            
            // Turbulence
            float turbulence = fbm(float3(centeredUV * 4.0 + float2(time * 0.3, cloudBase), time * 0.2));
            
            // Mushroom cap shape
            float capDist = length(float2(centeredUV.x * (1.0 + uv.y * 2.0), uv.y - 0.4 + cloudBase * 0.8));
            float capWidth = 0.3 + 0.1 * sin(time + float(i));
            float cap = smoothstep(capWidth, capWidth - 0.15, capDist);
            
            // Stem
            float stem = smoothstep(0.08, 0.0, abs(centeredUV.x)) * smoothstep(0.3, 0.0, uv.y - 0.3 + cloudBase * 0.5);
            
            // Combine
            float cloudDensity = max(cap, stem) * (0.5 + 0.5 * turbulence);
            
            // Color
            float3 cloudColor = nuclearPalette(0.3 + 0.2 * turbulence, 1.0);
            color = mix(color, cloudColor * intensity, cloudDensity * 0.7);
        }
    }
    
    // Smoke trails
    float smokeTime = mod(time * 0.3, 8.0);
    for (int i = 0; i < 5; i++) {
        float trailTime = smokeTime - float(i) * 1.5;
        if (trailTime < 0.0 || trailTime > 4.0) continue;
        
        float2 trailPos = float2(
            sin(time * 0.5 + float(i) * 1.5) * 0.2,
            -0.3 + trailTime * 0.12
        );
        float2 toTrail = centeredUV - trailPos;
        
        float trailNoise = fbm(float3(centeredUV * 6.0 + float(i), time, time * 0.5));
        float trailWidth = 0.05 * (1.0 + trailNoise);
        float trailDensity = exp(-length(toTrail) / trailWidth);
        float trailFade = 1.0 - trailTime / 4.0;
        
        float3 smokeColor = float3(0.15, 0.12, 0.1) * (0.5 + 0.5 * trailNoise);
        color = mix(color, smokeColor, trailDensity * trailFade * 0.5);
    }
    
    // Nuclear flash effect
    float flash = flashIntensity(time, audio);
    float3 flashColor = float3(1.0, 0.95, 0.8) * flash * intensity;
    color += flashColor;
    
    // Ground radiation glow
    float glow = groundGlow(uv, time);
    float3 glowColor = float3(0.8, 0.4, 0.1) * glow * intensity;
    color += glowColor;
    
    // Add audio-reactive particles/embers
    float emberCount = floor(uniforms.bass * 50.0);
    for (float i = 0.0; i < 20.0; i++) {
        float emberSeed = i * 12.9898;
        float emberX = fract(sin(emberSeed + time) * 43758.5453);
        float emberY = fract(sin(emberSeed * 1.5 + time * 1.2) * 43758.5453) * 0.6;
        float emberLife = fract(sin(time + emberSeed) * 43758.5453);
        
        if (emberY < 0.35 && emberLife > 0.5) {
            float2 emberPos = float2(emberX, emberY);
            float emberDist = length(centeredUV - emberPos);
            float emberSize = 0.005 * (1.0 + sin(time * 10.0));
            
            if (emberDist < emberSize) {
                float emberIntensity = (1.0 - emberDist / emberSize) * (emberLife - 0.5) * 2.0;
                float3 emberColor = float3(1.0, 0.5, 0.1) * emberIntensity * uniforms.bass;
                color += emberColor;
            }
        }
    }
    
    // Shockwave ring
    float shockwaveRadius = mod(time * 0.8, 2.0);
    float shockwaveWidth = 0.03;
    float shockwave = smoothstep(shockwaveRadius - shockwaveWidth, shockwaveRadius, length(centeredUV - float2(0.0, -0.2)));
    shockwave *= smoothstep(shockwaveRadius, shockwaveRadius - shockwaveWidth, length(centeredUV - float2(0.0, -0.2)));
    
    if (shockwave > 0.0 && shockwaveRadius < 1.0) {
        float3 shockColor = float3(1.0, 0.8, 0.4) * shockwave * intensity;
        color += shockColor;
    }
    
    // Vignette
    float vignette = 1.0 - length(uv - 0.5) * 0.8;
    color *= vignette;
    
    // Pulse with heartbeat
    float heartbeat = 0.8 + 0.2 * sin(time * 8.0);
    color *= heartbeat;
    
    // Final color adjustment
    color *= 1.2;
    
    return float4(color, 1.0);
}

// Vertex shader
vertex VertexOut falloutVertex(
    VertexIn in [[stage_in]],
    constant float4x4& viewProjection [[buffer(1)]]
) {
    VertexOut out;
    out.position = viewProjection * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    return out;
}
