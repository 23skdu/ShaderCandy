// Owl 3D - Night Watch with 3D Owls
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

using namespace ShaderUtils;

// Helper for ellipsoid
float sdEllipsoid(float3 p, float3 r) {
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
}

// Helper for cone
float sdCone(float3 p, float2 c) {
    float q = length(p.xz);
    return dot(c, float2(q, p.y));
}

// Owl SDF with detailed features
float owlSDF(float3 p, float time, float headRotationY) {
    float d = 1e10;
    
    // Body (egg-shaped)
    float3 bodyP = p - float3(0.0, -0.3, 0.0);
    float body = sdEllipsoid(bodyP, float3(0.5, 0.7, 0.45));
    
    // Apply head rotation
    float3 headCenter = float3(0.0, 0.5, 0.0);
    float3 headP = p - headCenter;
    
    // Rotate head around Y axis
    float c = cos(headRotationY);
    float s = sin(headRotationY);
    float2 rotatedXZ = float2(
        headP.x * c - headP.z * s,
        headP.x * s + headP.z * c
    );
    headP.x = rotatedXZ.x;
    headP.z = rotatedXZ.y;
    
    // Head (large, round)
    float head = sdSphere(headP, 0.42);
    
    // Facial disc (the flat face)
    float3 faceP = headP - float3(0.0, 0.0, 0.25);
    float faceDisc = length(faceP.xy) - 0.38;
    faceDisc = max(faceDisc, abs(faceP.z) - 0.05);
    
    // Ear tufts
    float3 tuftLP = headP - float3(-0.3, 0.35, 0.0);
    float3 tuftRP = headP - float3(0.3, 0.35, 0.0);
    // Pointed ear tufts
    float tuftL = length(tuftLP) - 0.12;
    tuftL = max(tuftL, -(headP.y - 0.35)); // Flat bottom
    float tuftR = length(tuftRP) - 0.12;
    tuftR = max(tuftR, -(headP.y - 0.35));
    
    // Beak (hooked)
    float3 beakP = headP - float3(0.0, -0.15, 0.35);
    float beak = sdCone(beakP, float2(0.08, 0.15));
    beak = max(beak, beakP.z - 0.1); // Hook
    
    // Large forward-facing eyes
    float3 eyeLP = headP - float3(-0.18, 0.1, 0.32);
    float3 eyeRP = headP - float3(0.18, 0.1, 0.32);
    float eyeL = sdSphere(eyeLP, 0.18);
    float eyeR = sdSphere(eyeRP, 0.18);
    
    // Eye rims
    float eyeRimL = sdSphere(eyeLP, 0.2);
    float eyeRimR = sdSphere(eyeRP, 0.2);
    eyeRimL = max(eyeRimL, -eyeL);
    eyeRimR = max(eyeRimR, -eyeR);
    
    // Wings (folded)
    float3 wingLP = bodyP - float3(-0.45, 0.1, 0.0);
    float3 wingRP = bodyP - float3(0.45, 0.1, 0.0);
    float wingL = sdEllipsoid(wingLP, float3(0.15, 0.5, 0.4));
    float wingR = sdEllipsoid(wingRP, float3(0.15, 0.5, 0.4));
    
    // Tail feathers
    float3 tailP = bodyP - float3(0.0, -0.5, -0.3);
    float tail = sdBox(tailP, float3(0.3, 0.15, 0.2));
    
    // Talons
    float3 talonLP = bodyP - float3(-0.2, -0.75, 0.1);
    float3 talonRP = bodyP - float3(0.2, -0.75, 0.1);
    float talonL = sdBox(talonLP, float3(0.08, 0.1, 0.12));
    float talonR = sdBox(talonRP, float3(0.08, 0.1, 0.12));
    
    d = min(body, head);
    d = min(d, tuftL);
    d = min(d, tuftR);
    d = min(d, beak);
    d = min(d, eyeL);
    d = min(d, eyeR);
    d = min(d, eyeRimL);
    d = min(d, eyeRimR);
    d = min(d, wingL);
    d = min(d, wingR);
    d = min(d, tail);
    d = min(d, talonL);
    d = min(d, talonR);
    
    return d;
}

float map(float3 p, float time) {
    float d = 1e10;
    
    // Tree branch
    float3 branchP = p;
    // Main branch
    float branch = length(branchP.xy - float2(0.0, -0.8)) - 0.25;
    branch = max(branch, abs(branchP.z) - 3.0);
    
    // Branch texture (bark)
    float bark = sin(branchP.x * 20.0 + branchP.z * 5.0) * 0.02;
    branch += bark;
    
    // Side branches
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 sideBranchP = branchP - float3((fi - 1.0) * 0.8, -0.6, -0.5 + fi * 0.3);
        float sideBranch = length(sideBranchP.xy) - 0.12;
        sideBranch = max(sideBranch, abs(sideBranchP.z) - 1.0);
        branch = min(branch, sideBranch);
    }
    
    // Multiple owls on branches
    float3 owlPositions[3] = {
        float3(0.0, 0.0, 0.0),
        float3(-1.2, 0.1, 0.3),
        float3(1.3, -0.1, -0.2)
    };
    
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 owlPos = owlPositions[i];
        
        // Each owl has different head rotation
        float headRot = sin(time * 0.5 + fi * 2.0) * 0.8 + 
                       sin(time * 1.2 + fi) * 0.3;
        
        float3 owlP = p - owlPos;
        // Rotate entire owl slightly
        float owlAngle = fi * 0.3;
        float2 rotatedOwl = float2(
            owlP.x * cos(owlAngle) - owlP.z * sin(owlAngle),
            owlP.x * sin(owlAngle) + owlP.z * cos(owlAngle)
        );
        owlP.x = rotatedOwl.x;
        owlP.z = rotatedOwl.y;
        
        float owl = owlSDF(owlP, time + fi, headRot);
        d = min(d, owl);
    }
    
    d = min(d, branch);
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    // Camera slowly orbits
    float camAngle = t * 0.1;
    float3 ro = float3(
        3.0 * sin(camAngle),
        0.5 + sin(t * 0.2) * 0.3,
        3.0 * cos(camAngle)
    );
    
    float3 target = float3(0.0, -0.2, 0.0);
    float3 fwd = normalize(target - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    float dTotal = 0.0;
    float d;
    
    for(int i = 0; i < 80; i++) {
        float3 p = ro + rd * dTotal;
        d = map(p, t);
        
        if(d < 0.001 || dTotal > 15.0) break;
        dTotal += d * 0.7;
    }
    
    // Night sky gradient
    float3 skyColor = mix(
        float3(0.02, 0.02, 0.08),
        float3(0.05, 0.05, 0.15),
        in.texCoord.y
    );
    float3 color = skyColor;
    
    if(dTotal < 15.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        // Moon light
        float3 moonPos = float3(5.0, 8.0, -5.0);
        float3 toMoon = normalize(moonPos - p);
        float diff = max(dot(n, toMoon), 0.0);
        float spec = pow(max(dot(reflect(-toMoon, n), -rd), 0.0), 16.0);
        
        // Material detection
        float3 baseColor = float3(0.0);
        float emissive = 0.0;
        
        // Check if we hit an owl
        bool hitOwl = false;
        float3 owlPositions[3] = {
            float3(0.0, 0.0, 0.0),
            float3(-1.2, 0.1, 0.3),
            float3(1.3, -0.1, -0.2)
        };
        
        for(int i = 0; i < 3; i++) {
            float fi = float(i);
            float3 owlPos = owlPositions[i];
            
            if(length(p - owlPos) < 0.8) {
                hitOwl = true;
                float3 owlP = p - owlPos;
                
                // Body feathers
                baseColor = float3(0.25, 0.2, 0.15);
                
                // Feather pattern
                float feather = snoise(owlP * 8.0 + t * 0.1);
                baseColor = mix(baseColor, baseColor * 0.8, feather * 0.3);
                
                // Lighter belly
                if(owlP.y < -0.2 && abs(owlP.x) < 0.3) {
                    baseColor = float3(0.4, 0.35, 0.28);
                }
                
                // Facial disc
                if(owlP.y > 0.1 && owlP.z > 0.2 && length(owlP.xy - float2(0.0, 0.5)) < 0.4) {
                    baseColor = float3(0.35, 0.3, 0.22);
                    // Concentric pattern on face
                    float facePattern = sin(length(owlP.xy - float2(0.0, 0.5)) * 15.0);
                    baseColor *= 0.9 + 0.1 * facePattern;
                }
                
                // Eyes (glowing!)
                float3 eyeLP = owlP - float3(-0.18, 0.6, 0.3);
                float3 eyeRP = owlP - float3(0.18, 0.6, 0.3);
                float distToEyeL = length(eyeLP);
                float distToEyeR = length(eyeRP);
                
                if(distToEyeL < 0.18 || distToEyeR < 0.18) {
                    // Eye glow
                    baseColor = float3(1.0, 0.85, 0.1); // Golden yellow
                    emissive = 0.5;
                    
                    // Pupil
                    if(distToEyeL < 0.08 || distToEyeR < 0.08) {
                        baseColor = float3(0.0, 0.0, 0.05);
                        emissive = 0.0;
                    }
                }
                
                // Beak
                float3 beakP = owlP - float3(0.0, 0.35, 0.4);
                if(length(beakP) < 0.1 && beakP.y < 0.0) {
                    baseColor = float3(0.15, 0.1, 0.05); // Dark beak
                }
                
                // Talons
                if(owlP.y < -0.6 && abs(owlP.x) < 0.25) {
                    baseColor = float3(0.6, 0.5, 0.3); // Yellow talons
                }
            }
        }
        
        // Branch
        if(!hitOwl) {
            baseColor = float3(0.15, 0.1, 0.06);
            // Bark texture
            float barkNoise = snoise(p * 15.0);
            baseColor *= 0.8 + 0.4 * barkNoise;
        }
        
        color = baseColor * (diff * 0.8 + 0.1);
        color += float3(1.0) * spec * 0.3;
        color += baseColor * emissive;
        
        // Fog
        float3 fogColor = skyColor;
        color = mix(color, fogColor, 1.0 - exp(-dTotal * 0.15));
    }
    
    // Background stars
    for(int i = 0; i < 50; i++) {
        float fi = float(i);
        float2 starPos = float2(
            fract(fi * 0.37 + 0.13) * 4.0 - 2.0,
            fract(fi * 0.23 + 0.07) * 2.0 - 1.0
        );
        float starSize = 0.003 + fract(fi * 0.19) * 0.003;
        float star = smoothstep(starSize, 0.0, length(uv - starPos));
        float twinkle = 0.5 + 0.5 * sin(t * 2.0 + fi * 3.0);
        color += float3(0.9, 0.95, 1.0) * star * twinkle;
    }
    
    // Moon
    float2 moonUV = float2(0.6, 0.7);
    float moonDist = length(uv - moonUV);
    float moon = smoothstep(0.12, 0.11, moonDist);
    color += float3(0.95, 0.95, 0.9) * moon;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}