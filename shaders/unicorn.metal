#include "ShaderInterop.h"
#include "base/utils.metal"


// Unicorn 3D - Magical creature with flowing mane and glowing horn

#include <metal_stdlib>
using namespace metal;

using namespace ShaderUtils;

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



// Helper for ellipsoid
float sdEllipsoid(float3 p, float3 r) {
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
}

// Unicorn SDF
float unicornSDF(float3 p, float time) {
    float d = 1e10;
    
    // Body (horse-like)
    float3 bodyP = p - float3(0.0, -0.2, 0.0);
    float body = sdEllipsoid(bodyP, float3(0.5, 0.4, 0.8));
    
    // Neck (arched)
    float3 neckP = p - float3(0.0, 0.4, 0.5);
    // Rotate neck upward
    float neckAngle = 0.5;
    float2 neckRot = float2(
        neckP.y * cos(neckAngle) - neckP.z * sin(neckAngle),
        neckP.y * sin(neckAngle) + neckP.z * cos(neckAngle)
    );
    neckP.y = neckRot.x;
    neckP.z = neckRot.y;
    float neck = sdEllipsoid(neckP, float3(0.2, 0.5, 0.25));
    
    // Head
    float3 headP = p - float3(0.0, 0.8, 0.7);
    float head = sdEllipsoid(headP, float3(0.22, 0.18, 0.35));
    
    // Snout
    float3 snoutP = p - float3(0.0, 0.75, 1.0);
    float snout = sdEllipsoid(snoutP, float3(0.15, 0.12, 0.2));
    
    // Ears
    float3 earLP = p - float3(-0.1, 1.0, 0.65);
    float3 earRP = p - float3(0.1, 1.0, 0.65);
    float earL = sdEllipsoid(earLP, float3(0.04, 0.12, 0.04));
    float earR = sdEllipsoid(earRP, float3(0.04, 0.12, 0.04));
    
    // THE HORN (magical spiral)
    float3 hornP = p - float3(0.0, 0.95, 0.8);
    // Spiral twist
    float spiralAngle = hornP.y * 8.0 + time * 2.0;
    float2 hornRot = float2(
        hornP.x * cos(spiralAngle) - hornP.z * sin(spiralAngle),
        hornP.x * sin(spiralAngle) + hornP.z * cos(spiralAngle)
    );
    hornP.x = hornRot.x * 0.7;
    hornP.z = hornRot.y * 0.7;
    float horn = sdCone(hornP, float2(0.04 + hornP.y * 0.02, 0.35));
    
    // Flowing mane
    float mane = 1e10;
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float3 maneP = p - float3(
            sin(fi * 0.4) * 0.15,
            0.6 + fi * 0.08 + sin(time * 2.0 + fi) * 0.02,
            0.4 + fi * 0.05
        );
        // Flow animation
        maneP.x += sin(time * 3.0 + fi * 0.5) * 0.05 * fi;
        
        float maneStrand = sdEllipsoid(maneP, float3(0.06 - fi * 0.005, 0.08, 0.04));
        mane = min(mane, maneStrand);
    }
    
    // Tail (flowing)
    float tail = 1e10;
    for(int i = 0; i < 6; i++) {
        float fi = float(i);
        float3 tailP = p - float3(
            sin(time * 1.5 + fi * 0.3) * 0.08 * fi,
            -0.3 - fi * 0.1,
            -0.7 - fi * 0.08
        );
        float tailStrand = sdEllipsoid(tailP, float3(0.05, 0.06, 0.04));
        tail = min(tail, tailStrand);
    }
    
    // Legs
    float3 legFLP = p - float3(-0.25, -0.7, 0.4);
    float3 legFRP = p - float3(0.25, -0.7, 0.4);
    float3 legBLP = p - float3(-0.25, -0.7, -0.4);
    float3 legBRP = p - float3(0.25, -0.7, -0.4);
    
    float legFL = sdEllipsoid(legFLP, float3(0.1, 0.5, 0.1));
    float legFR = sdEllipsoid(legFRP, float3(0.1, 0.5, 0.1));
    float legBL = sdEllipsoid(legBLP, float3(0.11, 0.5, 0.11));
    float legBR = sdEllipsoid(legBRP, float3(0.11, 0.5, 0.11));
    
    // Hooves
    float3 hoofFLP = legFLP - float3(0.0, -0.5, 0.0);
    float3 hoofFRP = legFRP - float3(0.0, -0.5, 0.0);
    float hoofFL = sdEllipsoid(hoofFLP, float3(0.11, 0.08, 0.11));
    float hoofFR = sdEllipsoid(hoofFRP, float3(0.11, 0.08, 0.11));
    
    d = min(body, neck);
    d = min(d, head);
    d = min(d, snout);
    d = min(d, earL);
    d = min(d, earR);
    d = min(d, horn);
    d = min(d, mane);
    d = min(d, tail);
    d = min(d, legFL);
    d = min(d, legFR);
    d = min(d, legBL);
    d = min(d, legBR);
    d = min(d, hoofFL);
    d = min(d, hoofFR);
    
    return d;
}

// Helper for cone
float sdCone(float3 p, float2 c) {
    float q = length(p.xz);
    return dot(c, float2(q, p.y));
}

// Magical particles
float3 magicalParticles(float3 p, float time) {
    float3 color = float3(0.0);
    
    for(int i = 0; i < 20; i++) {
        float fi = float(i);
        float3 particlePos = float3(
            sin(time * 0.5 + fi * 2.0) * 2.0,
            cos(time * 0.3 + fi * 1.5) * 1.5 + fi * 0.1,
            sin(time * 0.4 + fi) * 2.0
        );
        
        float dist = length(p - particlePos);
        float particle = exp(-dist * 2.0) * (0.5 + 0.5 * sin(time * 4.0 + fi * 3.0));
        
        float3 particleColor = hsv2rgb(float3(0.8 + fi * 0.02, 0.8, 1.0));
        color += particleColor * particle * 0.1;
    }
    
    return color;
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
    
    // Camera orbit around unicorn
    float camAngle = t * 0.15;
    float3 ro = float3(
        4.0 * sin(camAngle),
        1.0 + sin(t * 0.2) * 0.3,
        4.0 * cos(camAngle)
    );
    
    float3 target = float3(0.0, 0.0, 0.0);
    float3 fwd = normalize(target - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    float3 color = float3(0.0);
    float dTotal = 0.0;
    float d;
    float3 accumulatedGlow = float3(0.0);
    
    // Raymarch
    for(int i = 0; i < 80; i++) {
        float3 p = ro + rd * dTotal;
        d = unicornSDF(p, t);
        
        // Horn glow accumulation
        float3 hornP = p - float3(0.0, 0.95, 0.8);
        float hornDist = length(hornP);
        accumulatedGlow += float3(1.0, 0.8, 1.0) * 0.02 / (1.0 + hornDist * 3.0);
        
        if(d < 0.001 || dTotal > 20.0) break;
        dTotal += d * 0.7;
    }
    
    if(dTotal < 20.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            unicornSDF(p + float3(0.01,0,0), t) - unicornSDF(p - float3(0.01,0,0), t),
            unicornSDF(p + float3(0,0.01,0), t) - unicornSDF(p - float3(0,0.01,0), t),
            unicornSDF(p + float3(0,0,0.01), t) - unicornSDF(p - float3(0,0,0.01), t)
        ));
        
        // Lighting
        float3 lightPos = float3(5.0, 8.0, -5.0);
        float3 toLight = normalize(lightPos - p);
        float diff = max(dot(n, toLight), 0.0);
        float spec = pow(max(dot(reflect(-toLight, n), -rd), 0.0), 32.0);
        
        // Rainbow lighting for magical effect
        float rainbowAngle = atan2(n.y, n.x) + t;
        float3 rainbowLight = hsv2rgb(float3(fract(rainbowAngle * 0.1), 0.6, 0.4));
        
        // Material detection
        float3 baseColor = float3(0.95, 0.95, 1.0); // White coat
        float emissive = 0.0;
        
        // Check for different body parts
        float3 hornP = p - float3(0.0, 0.95, 0.8);
        float3 maneP = p - float3(0.0, 0.6, 0.4);
        float3 tailP = p - float3(0.0, -0.3, -0.7);
        
        // Horn - GLOWING with spiral pattern
        if(length(hornP) < 0.4 && hornP.y > 0.0) {
            float spiral = sin(atan2(hornP.x, hornP.z) * 3.0 + hornP.y * 10.0 + t * 3.0);
            baseColor = mix(
                float3(1.0, 0.9, 1.0),
                float3(0.9, 0.7, 1.0),
                spiral * 0.5 + 0.5
            );
            emissive = 0.4 + 0.3 * sin(t * 5.0);
        }
        
        // Mane and tail - rainbow gradient
        if(length(maneP) < 0.4 || (p.y > 0.4 && p.z > 0.3)) {
            float maneHue = fract(p.y * 0.5 + t * 0.2);
            baseColor = hsv2rgb(float3(maneHue, 0.7, 0.9));
        }
        if(length(tailP) < 0.5 || (p.y < -0.2 && p.z < -0.5)) {
            float tailHue = fract(p.y * 0.5 - t * 0.15 + 0.5);
            baseColor = hsv2rgb(float3(tailHue, 0.7, 0.9));
        }
        
        // Hooves
        if(p.y < -0.7) {
            baseColor = float3(0.3, 0.25, 0.3); // Dark purple-gray
        }
        
        // Eyes
        float3 eyeLP = p - float3(-0.08, 0.82, 1.0);
        float3 eyeRP = p - float3(0.08, 0.82, 1.0);
        if(length(eyeLP) < 0.08 || length(eyeRP) < 0.08) {
            baseColor = float3(0.8, 0.6, 0.9); // Purple eyes
            // Pupil
            if(length(eyeLP) < 0.03 || length(eyeRP) < 0.03) {
                baseColor = float3(0.1, 0.05, 0.15);
            }
        }
        
        color = baseColor * (diff + 0.2);
        color += rainbowLight * 0.3;
        color += float3(1.0) * spec * 0.5;
        color += baseColor * emissive;
        
        // Magical aura on surface
        float aura = snoise(p * 3.0 + t);
        color += hsv2rgb(float3(fract(t * 0.1), 0.6, 0.5)) * aura * 0.2;
    }
    
    // Add accumulated horn glow
    color += accumulatedGlow * u_aura;
    
    // Add magical particles
    float3 particles = magicalParticles(ro + rd * dTotal, t);
    color += particles * u_sparkle;
    
    // Magical background
    float3 bgColor = float3(0.1, 0.05, 0.15);
    bgColor += hsv2rgb(float3(fract(t * 0.05 + length(uv) * 0.1), 0.5, 0.2));
    
    // Fog
    color = mix(color, bgColor, 1.0 - exp(-dTotal * 0.12));
    
    // Sparkles everywhere
    for(int i = 0; i < 30; i++) {
        float fi = float(i);
        float2 sparkPos = p.xy + float2(
            sin(t * 0.4 + fi * 2.0) * 0.8,
            cos(t * 0.5 + fi * 1.5) * 0.6
        );
        float spark = smoothstep(0.01, 0.0, length(sparkPos));
        spark *= 0.5 + 0.5 * sin(t * 6.0 + fi * 4.0);
        color += hsv2rgb(float3(0.75 + fi * 0.01, 0.6, 1.0)) * spark * u_sparkle;
    }
    
    // Intensity effects
    color *= u.intensity;
    
    return float4(color, 1.0);
}