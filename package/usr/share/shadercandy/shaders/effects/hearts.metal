#include "ShaderInterop.h"
#include "../base/utils.metal"


//
//  hearts.metal
//  ShaderCandy
//
//  Festive 3D Hearts from all directions for Valentine's Day
//

#include <metal_stdlib>
using namespace metal;

using namespace ShaderUtils;

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

float3 custom_rotateX(float3 p, float a) {
    float c = cos(a);
    float s = sin(a);
    float3 q = p;
    q.y = c * p.y - s * p.z;
    q.z = s * p.y + c * p.z;
    return q;
}

// Map a single heart
float singleHeart(float3 p, float3 offset, float rotation, float scale, float pulse, float time) {
    float3 q = p - offset;
    
    // Rotate
    q = custom_rotateY(q, rotation);
    q = custom_rotateX(q, rotation * 0.5);
    
    // Scale with pulse
    q /= scale * pulse;
    
    return sdHeart(q) * scale * pulse;
}

// Map the scene with hearts from all directions
float map(float3 p, float time) {
    float d = 1e10;
    
    // Hearts coming from all directions
    // Center cluster
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        
        // Create hearts in 3D spherical distribution
        float theta = fi * 0.785 + time * 0.1;
        float phi = fi * 1.3 + time * 0.15;
        
        float3 direction = float3(
            sin(theta) * cos(phi),
            sin(theta) * sin(phi),
            cos(theta)
        );
        
        // Position at various distances
        float distance = 2.0 + sin(fi * 2.0 + time) * 0.5;
        float3 offset = direction * distance;
        
        // Add inward movement
        float inwardPhase = fract(time * 0.1 + fi * 0.125);
        offset *= 1.0 - inwardPhase * 0.7;
        
        float rotation = time + fi;
        float scale = 0.4 + sin(fi * 3.0) * 0.15;
        float pulse = 1.0 + 0.15 * sin(time * 4.0 + fi * 2.0);
        
        float heart = singleHeart(p, offset, rotation, scale, pulse, time);
        d = min(d, heart);
    }
    
    // Additional hearts from sides
    for(int i = 0; i < 6; i++) {
        float fi = float(i + 8);
        
        // Left and right streams
        float side = (i % 2 == 0) ? -1.0 : 1.0;
        float3 offset = float3(
            side * (3.0 + sin(time + fi) * 0.5),
            sin(fi * 1.5 + time * 0.5) * 2.0,
            cos(fi * 1.2) * 2.0
        );
        
        float rotation = time * 0.8 + fi;
        float scale = 0.35;
        float pulse = 1.0 + 0.1 * sin(time * 3.0 + fi);
        
        float heart = singleHeart(p, offset, rotation, scale, pulse, time);
        d = min(d, heart);
    }
    
    // Hearts from top and bottom
    for(int i = 0; i < 6; i++) {
        float fi = float(i + 14);
        
        float vertical = (i % 2 == 0) ? 1.0 : -1.0;
        float3 offset = float3(
            cos(fi * 1.1 + time) * 2.0,
            vertical * (3.0 + sin(time * 0.7 + fi) * 0.5),
            sin(fi * 1.3) * 2.0
        );
        
        float rotation = -time + fi;
        float scale = 0.3 + sin(fi * 2.0) * 0.1;
        float pulse = 1.0 + 0.2 * sin(time * 5.0 + fi);
        
        float heart = singleHeart(p, offset, rotation, scale, pulse, time);
        d = min(d, heart);
    }
    
    // Background hearts (further away)
    for(int i = 0; i < 10; i++) {
        float fi = float(i + 20);
        
        float3 offset = float3(
            sin(fi * 0.8 + time * 0.3) * 4.0,
            cos(fi * 0.6 + time * 0.2) * 3.0,
            -5.0 - fi * 0.5 + fract(time * 0.2 + fi * 0.1) * 5.0
        );
        
        float rotation = time * 0.5 + fi;
        float scale = 0.5 + sin(fi) * 0.2;
        float pulse = 1.0 + 0.1 * sin(time * 2.0 + fi);
        
        float heart = singleHeart(p, offset, rotation, scale, pulse, time);
        d = min(d, heart);
    }
    
    return d;
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
    
    // 2. Camera Setup - rotating to see hearts from all sides
    float camAngle = time * 0.15;
    float camRadius = 4.0 + sin(time * 0.3) * 1.0;
    float3 ro = float3(
        sin(camAngle) * camRadius,
        sin(time * 0.2) * 2.0,
        cos(camAngle) * camRadius
    );
    
    float3 target = float3(0.0, 0.0, 0.0);
    float3 fwd = normalize(target - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // 3. Raymarching Loop
    float t = 0.0;
    float tmax = 25.0;
    float d = 0.0;
    float3 accumulatedColor = float3(0.0);
    
    int i = 0;
    for(i = 0; i < 80; i++) {
        float3 p = ro + rd * t;
        d = map(p, time);
        
        // Accumulate glow from nearby hearts
        accumulatedColor += float3(1.0, 0.3, 0.5) * 0.005 / (1.0 + d * 5.0);
        
        if(d < 0.001 || t > tmax) break;
        t += d * 0.7;
    }
    
    // 4. Shading / Lighting
    float3 color = float3(0.0);
    
    if(t < tmax) {
        float3 p = ro + rd * t;
        float3 n = calcNormal(p, time);
        float3 lightPos = float3(5.0, 5.0, -5.0);
        float3 l = normalize(lightPos - p);
        
        // Material Properties
        float3 ambient = float3(0.08, 0.02, 0.04);
        float diffuse = max(dot(n, l), 0.0);
        float specular = pow(max(dot(reflect(-l, n), -rd), 0.0), 32.0);
        float rim = 1.0 - max(dot(n, -rd), 0.0);
        rim = pow(rim, 2.0);
        
        // Heart color with variation
        float colorVar = sin(p.x * 0.5 + time) * 0.3 + sin(p.y * 0.3) * 0.2;
        float3 objColor = mix(
            float3(0.9, 0.1, 0.3),  // Red
            float3(1.0, 0.2, 0.5),  // Pink
            colorVar * 0.5 + 0.5
        );
        
        color = ambient + objColor * diffuse + float3(1.0, 0.9, 0.9) * specular * 0.6;
        color += float3(1.0, 0.4, 0.6) * rim * 0.6;
        
        // Fog based on distance
        float fog = 1.0 - exp(-t * 0.06);
        float3 fogColor = float3(0.15, 0.02, 0.08);
        color = mix(color, fogColor, fog);
        
    } else {
        // Background with gradient
        float len = length(uv);
        color = mix(float3(0.25, 0.03, 0.12), float3(0.08, 0.0, 0.04), len);
        
        // Background hearts as bokeh
        for(int j = 0; j < 8; j++) {
            float fj = float(j);
            float2 bokehPos = float2(
                sin(fj * 2.0 + time * 0.3) * 0.7,
                cos(fj * 1.5 + time * 0.2) * 0.5
            );
            float bokehSize = 0.05 + sin(fj * 3.0 + time) * 0.02;
            float bokeh = smoothstep(bokehSize, 0.0, length(uv - bokehPos));
            color += float3(0.9, 0.3, 0.5) * bokeh * 0.15;
        }
    }
    
    // Add accumulated glow
    color += accumulatedColor;
    
    // Add sparkle particles
    for(int k = 0; k < 15; k++) {
        float fk = float(k);
        float2 sparkPos = uv + float2(
            sin(time * 0.5 + fk * 2.0) * 0.8,
            cos(time * 0.4 + fk * 1.5) * 0.6
        );
        float spark = smoothstep(0.015, 0.0, length(sparkPos));
        spark *= 0.5 + 0.5 * sin(time * 4.0 + fk * 3.0);
        color += float3(1.0, 0.8, 0.9) * spark;
    }
    
    // 5. Final Output
    return float4(color * uniforms.alpha, uniforms.alpha);
}
