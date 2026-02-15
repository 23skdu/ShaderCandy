// Dragon 3D - Monster Eye with Blinking
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

using namespace ShaderUtils;

// 3D Eye SDF with eyelids
float eyeSDF(float3 p, float blink, float t) {
    float d = 1e10;
    
    // Eyeball (slightly flattened sphere)
    float3 eyeP = p - float3(0.0, 0.0, 0.0);
    float eyeball = length(eyeP) - 0.5;
    eyeball = max(eyeball, eyeP.z - 0.1); // Flatten front
    
    // Iris (slightly forward)
    float3 irisP = p - float3(0.0, 0.0, 0.35);
    float iris = length(irisP.xy) - 0.25;
    iris = max(iris, abs(irisP.z) - 0.05);
    
    // Pupil (center of iris)
    float3 pupilP = p - float3(0.0, 0.0, 0.38);
    float pupil = length(pupilP.xy) - 0.1;
    pupil = max(pupil, abs(pupilP.z) - 0.03);
    
    // Eyelids (hemispheres that close)
    float lidOpen = 1.0 - blink; // 0 = closed, 1 = open
    
    // Upper eyelid
    float3 upperLidP = p - float3(0.0, 0.3 * lidOpen, 0.0);
    float upperLid = length(upperLidP) - 0.52;
    upperLid = max(upperLid, -(p.y - 0.1)); // Cut below
    upperLid = max(upperLid, p.z - 0.1); // Cut front
    
    // Lower eyelid
    float3 lowerLidP = p - float3(0.0, -0.3 * lidOpen, 0.0);
    float lowerLid = length(lowerLidP) - 0.52;
    lowerLid = max(lowerLid, -(-p.y - 0.1)); // Cut above
    lowerLid = max(lowerLid, p.z - 0.1); // Cut front
    
    // Combine eye components
    d = eyeball;
    d = max(d, -iris); // Cut out iris
    d = min(d, iris);
    d = max(d, -pupil); // Cut out pupil from iris
    
    // Add eyelids
    d = min(d, upperLid);
    d = min(d, lowerLid);
    
    return d;
}

// Dragon scale texture
float dragonScale(float2 uv, float t) {
    float2 suv = uv * 10.0;
    float2 id = floor(suv);
    float2 gv = fract(suv) - 0.5;
    
    // Scale shape with variation
    float scaleD = length(gv + 0.1 * sin(id.y * 2.0 + id.x + t * 0.5));
    float scale = smoothstep(0.4, 0.3, scaleD);
    
    // Scale border
    float border = smoothstep(0.45, 0.4, scaleD) - scale;
    
    return scale + border * 0.3;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    // Blink animation (periodic)
    float blinkPhase = fract(t * 0.3);
    float blink = 0.0;
    if (blinkPhase < 0.1) {
        // Quick blink
        blink = sin(blinkPhase / 0.1 * 3.14159);
    }
    
    float3 color = float3(0.0);
    
    // Background scales
    float2 scaleUV = uv + float2(sin(t * 0.1) * 0.05, cos(t * 0.15) * 0.05);
    float scalePattern = dragonScale(scaleUV, t);
    float3 scaleCol = mix(float3(0.03, 0.08, 0.04), float3(0.08, 0.15, 0.08), scalePattern);
    
    // Eye socket shadow
    float eyeSocket = length(uv) - 0.7;
    eyeSocket = smoothstep(0.0, 0.3, eyeSocket);
    scaleCol *= eyeSocket;
    
    color = scaleCol;
    
    // 3D Eye raymarch
    float3 ro = float3(uv * 0.8, 2.0);
    float3 rd = float3(0.0, 0.0, -1.0);
    
    float d = 0.0;
    float td = 0.0;
    float3 eyeColor = float3(0.0);
    bool hitEye = false;
    
    for (int i = 0; i < 64; i++) {
        float3 p = ro + rd * td;
        d = eyeSDF(p, blink, t);
        
        if (d < 0.001 || td > 3.0) {
            hitEye = true;
            break;
        }
        td += d;
    }
    
    if (hitEye && td < 3.0) {
        float3 p = ro + rd * td;
        
        // Calculate normal
        float2 e = float2(0.001, 0.0);
        float3 normal = normalize(float3(
            eyeSDF(p + e.xyy, blink, t) - eyeSDF(p - e.xyy, blink, t),
            eyeSDF(p + e.yxy, blink, t) - eyeSDF(p - e.yxy, blink, t),
            eyeSDF(p + e.yyx, blink, t) - eyeSDF(p - e.yyx, blink, t)
        ));
        
        // Determine material
        float3 irisP = p - float3(0.0, 0.0, 0.35);
        float3 pupilP = p - float3(0.0, 0.0, 0.38);
        float distToPupil = length(pupilP.xy);
        float distToIris = length(irisP.xy);
        
        // Check if hitting eyelid
        float3 upperLidP = p - float3(0.0, 0.3 * (1.0 - blink), 0.0);
        float3 lowerLidP = p - float3(0.0, -0.3 * (1.0 - blink), 0.0);
        bool upperLid = length(upperLidP) < 0.55 && p.y > 0.1 && p.z < 0.15;
        bool lowerLid = length(lowerLidP) < 0.55 && p.y < -0.1 && p.z < 0.15;
        bool isEyelid = upperLid || lowerLid;
        
        float3 lightDir = normalize(float3(1.0, 1.0, -1.0));
        float diff = max(0.0, dot(normal, lightDir));
        float spec = pow(max(dot(reflect(-lightDir, normal), -rd), 0.0), 32.0);
        
        if (isEyelid) {
            // Eyelid color - darker scales
            eyeColor = float3(0.04, 0.1, 0.05) * (diff + 0.2);
            eyeColor += float3(0.1) * spec;
        } else if (distToPupil < 0.12) {
            // Pupil - black
            eyeColor = float3(0.0, 0.0, 0.02);
            // Small reflection in pupil
            float pupilReflect = pow(max(dot(reflect(-lightDir, normal), -rd), 0.0), 64.0);
            eyeColor += float3(0.1, 0.05, 0.0) * pupilReflect;
        } else if (distToIris < 0.28) {
            // Iris - fiery orange/red with animation
            float irisNoise = snoise(float3(irisP.xy * 5.0, t * 0.2));
            float3 irisBase = mix(
                float3(0.9, 0.3, 0.0),  // Orange
                float3(0.8, 0.1, 0.0),  // Red
                irisNoise * 0.5 + 0.5
            );
            
            // Iris pattern
            float angle = atan2(irisP.y, irisP.x);
            float radius = length(irisP.xy);
            float irisPattern = sin(angle * 8.0 + t) * sin(radius * 20.0);
            irisBase = mix(irisBase, irisBase * 0.7, irisPattern * 0.5 + 0.5);
            
            eyeColor = irisBase * (diff + 0.3);
            eyeColor += float3(1.0, 0.5, 0.0) * spec * 0.5;
        } else {
            // Sclera (white of eye) with slight tint
            float3 scleraCol = float3(0.9, 0.95, 0.85);
            // Add veins
            float vein = snoise(p * 10.0 + t * 0.1);
            scleraCol = mix(scleraCol, float3(0.8, 0.3, 0.2), smoothstep(0.6, 0.8, vein) * 0.3);
            
            eyeColor = scleraCol * (diff + 0.2);
            eyeColor += float3(1.0) * spec * 0.3;
        }
        
        color = mix(color, eyeColor, smoothstep(0.65, 0.0, length(uv)));
    }
    
    // Fire glow around eye (pulsing)
    float firePulse = 0.8 + 0.2 * sin(t * 3.0);
    float eyeGlow = 0.15 / (length(uv) + 0.15);
    color += float3(1.0, 0.2 + blink * 0.3, 0.0) * eyeGlow * firePulse;
    
    // Add embers/sparks
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float2 sparkPos = uv + float2(
            sin(t * 2.0 + fi * 2.0) * (0.5 + fi * 0.1),
            cos(t * 1.5 + fi * 1.5) * (0.3 + fi * 0.08) + t * 0.2
        );
        float spark = smoothstep(0.03, 0.0, length(sparkPos));
        color += float3(1.0, 0.4, 0.0) * spark * (0.5 + 0.5 * sin(t * 5.0 + fi));
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}