#include "ShaderInterop.h"


//
//  hearts.metal
//  ShaderCandy
//
//  Festive 3D Hearts for Valentine's Day
//

#include <metal_stdlib>
using namespace metal;

// Signed Distance Function for a 3D Heart
// Reference: Inigo Quilez
float sdHeart(float3 p) {
   float3 q = p;
   q.z *= 1.5; // flatten depth slightly
   q.y -= sqrt(abs(q.x)) * 0.5; // Heart shape distortion 
   return length(q) - 0.4;
}

// Rotation Matrix
float3 custom_rotateY(float3 p, float a) {
    float c = cos(a);
    float s = sin(a);
    float3 q = p;
    q.x = c * p.x + s * p.z;
    q.z = -s * p.x + c * p.z;
    return q;
}

// Map the scene
float map(float3 p, float time) {
    // 1. Domain Repetition (Instancing)
    float3 c = float3(2.5, 2.5, 2.5); // Spacing between hearts
    
    // Shift Y based on time to make them float up
    float3 q = p;
    q.y -= time * 0.5;
    
    // Get cell ID for unique animation per heart
    float3 id = floor((q + c * 0.5) / c);
    
    // Wrap space
    q = fmod(q + c * 0.5, c) - c * 0.5;
    
    // 2. Per-instance animation
    // Hash function for random offset
    float hash = fract(sin(dot(id, float3(12.9898, 78.233, 45.543))) * 43758.5453);
    
    // Rotate each heart differently
    float angle = time * (1.0 + hash) + hash * 6.28;
    q = custom_rotateY(q, angle);
    
    // Pulse animation (heartbeat)
    float pulse = 1.0 + 0.15 * sin(time * 3.0 + hash * 10.0);
    q /= pulse;
    
    // 3. SDF Evaluation
    return sdHeart(q) * pulse * 0.5; // Scale correction
}

// Calculate normal for lighting
float3 calcNormal(float3 p, float time) {
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + float3(e.x, 0, 0), time) - map(p - float3(e.x, 0, 0), time),
        map(p + float3(0, e.x, 0), time) - map(p - float3(0, e.x, 0), time),
        map(p + float3(0, 0, e.x), time) - map(p - float3(0, 0, e.x), time)
    ));
}

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    // 1. Setup Coordinates
    float2 uv = in.texCoord;
    uv -= 0.5;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float time = uniforms.time * uniforms.speed;
    
    // 2. Camera Setup
    float3 ro = float3(0.0, 0.0, -3.0); // Ray origin (camera position)
    float3 rd = normalize(float3(uv, 1.0)); // Ray direction (perspective)
    
    // 3. Raymarching Loop
    float t = 0.0;
    float tmax = 20.0;
    float d = 0.0;
    
    // Only 64 steps for performance
    int i = 0;
    for(i = 0; i < 64; i++) {
        float3 p = ro + rd * t;
        d = map(p, time);
        if(d < 0.001 || t > tmax) break;
        t += d * 0.8; // Step dampened to reduce overshooting
    }
    
    // 4. Shading / Lighting
    float3 color = float3(0.0);
    
    if(t < tmax) {
        float3 p = ro + rd * t;
        float3 n = calcNormal(p, time);
        float3 lightPos = float3(2.0, 5.0, -3.0);
        float3 l = normalize(lightPos - p);
        
        // Material Properties
        float3 ambient = float3(0.1, 0.02, 0.05); // Dark pink ambient
        float diffuse = max(dot(n, l), 0.0);
        float specular = pow(max(dot(reflect(-l, n), -rd), 0.0), 16.0); // Shiny
        float rim = 1.0 - max(dot(n, -rd), 0.0);
        rim = pow(rim, 3.0);
        
        // Heart color
        // Modulate color slightly by position for variety
        float3 objColor = float3(0.9, 0.1, 0.3); // Red/Pink base
        objColor = mix(objColor, float3(1.0, 0.4, 0.7), sin(p.y)*0.5+0.5);
        
        color = ambient + objColor * diffuse + float3(1.0, 0.9, 0.9) * specular * 0.5;
        color += float3(1.0, 0.5, 0.8) * rim * 0.8; // Rim light glow
        
        // Fog based on distance
        float fog = 1.0 - exp(-t * 0.08);
        float3 fogColor = float3(0.2, 0.05, 0.1); // Background pink
        color = mix(color, fogColor, fog);
        
    } else {
        // Background
        // Radial gradient
        float len = length(uv);
        color = mix(float3(0.3, 0.05, 0.15), float3(0.1, 0.0, 0.05), len);
    }
    
    // 5. Final Output
    return float4(color * uniforms.alpha, uniforms.alpha);
}
