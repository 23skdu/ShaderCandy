#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  area_51.metal
//  ShaderCandy
//
//  Aliens and UFO sighting at a secret desert base
//

using namespace ShaderUtils;

float ufoSDF(float3 p, float t) {
    // Rotating flying saucer
    p = rotateY(p, t * 0.5);
    float body = length(p * float3(1.0, 3.0, 1.0)) - 0.8;
    float ring = length(float2(length(p.xz) - 0.8, p.y)) - 0.05;
    float ufo = min(body, ring);
    
    // Dome
    float dome = length(p - float3(0, 0.1, 0)) - 0.4;
    dome = max(dome, p.y);
    return min(ufo, dome);
}

// Cow SDF
float cowSDF(float3 p, float t) {
    // Body
    float body = sdBox(p, float3(0.3, 0.2, 0.5));
    
    // Head
    float3 headP = p - float3(0.0, 0.15, 0.5);
    float head = sdBox(headP, float3(0.15, 0.15, 0.2));
    
    // Legs
    float3 leg1P = p - float3(-0.2, -0.25, 0.3);
    float3 leg2P = p - float3(0.2, -0.25, 0.3);
    float3 leg3P = p - float3(-0.2, -0.25, -0.3);
    float3 leg4P = p - float3(0.2, -0.25, -0.3);
    float leg1 = sdBox(leg1P, float3(0.06, 0.15, 0.06));
    float leg2 = sdBox(leg2P, float3(0.06, 0.15, 0.06));
    float leg3 = sdBox(leg3P, float3(0.06, 0.15, 0.06));
    float leg4 = sdBox(leg4P, float3(0.06, 0.15, 0.06));
    
    // Tail
    float3 tailP = p - float3(0.0, 0.1, -0.55);
    float tail = sdBox(tailP, float3(0.03, 0.15, 0.03));
    
    float cow = min(body, head);
    cow = min(cow, leg1);
    cow = min(cow, leg2);
    cow = min(cow, leg3);
    cow = min(cow, leg4);
    cow = min(cow, tail);
    
    return cow;
}

// Alien SDF (little green man)
float alienSDF(float3 p, float t) {
    // Big head
    float head = sdSphere(p - float3(0.0, 0.2, 0.0), 0.2);
    
    // Small body
    float body = sdSphere(p - float3(0.0, -0.15, 0.0), 0.12);
    
    // Big eyes
    float eye1 = sdSphere(p - float3(-0.08, 0.22, 0.15), 0.06);
    float eye2 = sdSphere(p - float3(0.08, 0.22, 0.15), 0.06);
    
    float alien = min(head, body);
    // Cut out eyes
    alien = max(alien, -eye1);
    alien = max(alien, -eye2);
    
    return alien;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Background: Desert Night with gradient
    float3 color = mix(float3(0.0, 0.0, 0.05), float3(0.08, 0.03, 0.15), in.texCoord.y);
    
    // Animated stars with twinkling
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 starUV = uv * (50.0 + fi * 20.0);
        float n = hash(floor(starUV).x + floor(starUV).y * 123.4 + fi * 456.7);
        float twinkle = 0.5 + 0.5 * sin(t * (2.0 + fi) + n * 10.0);
        if (n > 0.98 - fi * 0.01) {
            color += pow(hash(n + t), 10.0) * twinkle * (1.0 - fi * 0.2);
        }
    }
    
    // Moon
    float2 moonPos = float2(0.7, 0.7);
    float moonDist = length(uv - moonPos);
    float moon = smoothstep(0.15, 0.14, moonDist);
    color += float3(0.9, 0.9, 0.8) * moon;
    // Moon crater shadow
    float crater = smoothstep(0.03, 0.02, length(uv - moonPos - float2(0.03, 0.02)));
    color -= float3(0.1) * crater * moon;
    
    // Desert Ground Plane with more detail
    float groundNoise = 0.0;
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        groundNoise += noise(float2(uv.x * (2.0 + fi), t * 0.05 * (1.0 + fi))) * (0.1 / (1.0 + fi));
    }
    float ground = -0.6 + groundNoise;
    
    if (uv.y < ground) {
        // Sandy desert color
        color = mix(float3(0.15, 0.1, 0.05), float3(0.08, 0.05, 0.02), uv.y + 0.6);
        
        // Distant fence posts with warning signs
        float fencePattern = fract(uv.x * 8.0);
        if (fencePattern < 0.02) {
            color += float3(0.05); // Fence post
        }
        // Barbed wire
        if (abs(uv.y - ground + 0.05) < 0.005 && fract(uv.x * 40.0) < 0.5) {
            color += float3(0.1);
        }
    }
    
    // Cows grazing on the ground
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float2 cowPos = float2(-0.8 + fi * 0.5 + sin(t * 0.1 + fi) * 0.1, ground - 0.05);
        
        // Cow SDF raymarch
        float3 ro_cow = float3(uv.x - cowPos.x, uv.y - cowPos.y, 2.0);
        float3 rd_cow = float3(0.0, 0.0, -1.0);
        float d_cow = 0.0, t_cow = 0.0;
        
        for(int j = 0; j < 32; j++) {
            d_cow = cowSDF(ro_cow + rd_cow * t_cow, t);
            if(d_cow < 0.001 || t_cow > 5.0) break;
            t_cow += d_cow;
        }
        
        if(t_cow < 5.0 && uv.y < ground + 0.1) {
            // Cow color - white with black spots
            float3 cowColor = float3(0.9, 0.9, 0.85);
            float spotNoise = noise(ro_cow.xz * 5.0 + fi * 10.0);
            if(spotNoise > 0.6) cowColor = float3(0.1, 0.1, 0.1); // Black spots
            
            color = mix(color, cowColor, 0.9);
        }
    }
    
    // Multiple UFOs with different positions
    float3 ufoColors[4] = {
        float3(0.5, 0.5, 0.6),  // Silver
        float3(0.6, 0.4, 0.5),  // Rose gold
        float3(0.4, 0.5, 0.6),  // Blue-tinted
        float3(0.6, 0.6, 0.4)   // Gold
    };
    
    for(int ufoIdx = 0; ufoIdx < 4; ufoIdx++) {
        float fu = float(ufoIdx);
        
        // Each UFO has different movement pattern
        float ufoX = sin(t * (0.2 + fu * 0.1) + fu * 1.5) * (0.8 + fu * 0.3);
        float ufoY = 1.0 + fu * 0.3 + sin(t * (0.5 + fu * 0.2)) * 0.1;
        float ufoZ = -fu * 0.5;
        
        // The Beam for each UFO
        float beamDist = abs(uv.x - ufoX);
        float beamWidth = 0.1 + fu * 0.02;
        float beam = exp(-beamDist * (8.0 - fu)) * smoothstep(-1.0, ground + 1.5, uv.y);
        // Pulsing beam color
        float3 beamColor = float3(0.2, 1.0, 0.3) * (0.7 + 0.3 * sin(t * 3.0 + fu));
        color += beamColor * beam * (0.3 - fu * 0.05);
        
        // UFO Raymarch
        float3 ro = float3(0, ufoY, 3 + ufoZ);
        float3 rd = normalize(float3(uv.x - ufoX, uv.y - ufoY, -1.5));
        float d = 0.0, t_dist = 0.0;
        
        for(int i = 0; i < 40; i++) {
            d = ufoSDF(ro + rd * t_dist - float3(ufoX, ufoY, 0), t + fu);
            if(d < 0.01 || t_dist > 5.0) break;
            t_dist += d;
        }
        
        if(t_dist < 5.0) {
            float3 p = ro + rd * t_dist;
            color = mix(color, ufoColors[ufoIdx], 0.8);
            // Rotating Lights on UFO
            float lightPattern = sin(atan2(p.z, p.x) * (10.0 + fu * 2.0) + t * (5.0 + fu));
            if(lightPattern > 0.0) {
                color += float3(0.0, 1.0, 0.5) * (0.4 - fu * 0.08);
            }
            // Dome glow
            if(p.y > ufoY + 0.05) {
                color += float3(0.5, 0.8, 1.0) * 0.3;
            }
        }
    }
    
    // Aliens walking around
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 alienPos = float2(
            sin(t * 0.3 + fi * 2.0) * 0.4,
            ground - 0.08 + abs(sin(t * 4.0 + fi)) * 0.02 // Bouncing walk
        );
        
        float3 ro_alien = float3(uv.x - alienPos.x, uv.y - alienPos.y, 2.0);
        float3 rd_alien = float3(0.0, 0.0, -1.0);
        float d_alien = 0.0, t_alien = 0.0;
        
        for(int j = 0; j < 30; j++) {
            d_alien = alienSDF(ro_alien + rd_alien * t_alien, t);
            if(d_alien < 0.001 || t_alien > 5.0) break;
            t_alien += d_alien;
        }
        
        if(t_alien < 5.0 && uv.y < ground + 0.15) {
            // Green alien
            float3 alienColor = float3(0.2, 0.8, 0.2);
            // Big black eyes
            float3 p_alien = ro_alien + rd_alien * t_alien;
            float eye1 = sdSphere(p_alien - float3(-0.08, 0.22, 0.15), 0.06);
            float eye2 = sdSphere(p_alien - float3(0.08, 0.22, 0.15), 0.06);
            if(eye1 < 0.02 || eye2 < 0.02) alienColor = float3(0.0, 0.0, 0.1);
            
            color = mix(color, alienColor, 0.9);
        }
    }
    
    // "RESTRICTED AREA" warning lights
    if (uv.y > 0.75 && uv.y < 0.8) {
        float warningPulse = step(0.3, sin(t * 3.0 + uv.x * 5.0));
        color += float3(1.0, 0.0, 0.0) * warningPulse * 0.15;
    }
    
    // Searchlights from base
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float lightAngle = t * (0.5 + fi * 0.3) + fi * 3.14;
        float2 lightDir = float2(cos(lightAngle), sin(lightAngle * 0.3));
        float2 lightPos = float2(-0.9 + fi * 1.8, ground);
        
        float lightDist = length(uv - lightPos);
        float lightBeam = smoothstep(0.3, 0.0, abs(dot(normalize(uv - lightPos), float2(-lightDir.y, lightDir.x))));
        lightBeam *= exp(-lightDist * 2.0) * (0.5 + 0.5 * sin(t * 2.0 + fi));
        
        color += float3(0.9, 0.9, 0.7) * lightBeam * 0.2;
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
