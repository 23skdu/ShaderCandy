// Knights 3D - Chess Battle
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



// Simple Knight Piece SDF
float sdKnight(float3 p) {
    float base = sdBox(p - float3(0, -0.4, 0), float3(0.3, 0.1, 0.3));
    float body = length(p.xz) - 0.2 * (1.0 - p.y);
    body = max(body, abs(p.y) - 0.4);
    
    // Horse head
    float head = length(p - float3(0.1, 0.3, 0)) - 0.2;
    float snout = length(p - float3(0.3, 0.2, 0)) - 0.1;
    
    return min(base, min(body, min(head, snout)));
}

float map(float3 p, float time) {
    float d = p.y + 0.5; // Board
    
    // Chess pieces
    float3 p1 = p - float3(-1.0, 0.0, 0.0);
    p1.xz = p1.xz * cos(time*0.5) + float2(p1.z, -p1.x) * sin(time*0.5);
    d = min(d, sdKnight(p1));
    
    float3 p2 = p - float3(1.0, 0.0, 1.0);
    p2.xz = p2.xz * cos(-time*0.7) + float2(p2.z, -p2.x) * sin(-time*0.7);
    d = min(d, sdKnight(p2));
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float3 ro = float3(0, 2.0, -4.0);
    float3 rd = normalize(float3(uv, 1.5));
    rd = lookAt(ro, float3(0,0,0)) * rd;
    
    float t = 0.0;
    for(int i=0; i<64; i++) {
        float d = map(ro + rd*t, uniforms.time);
        if(d < 0.001 || t > 20.0) break;
        t += d;
    }
    
    float3 color = float3(0.1);
    if(t < 20.0) {
        float3 p = ro + rd * t;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), uniforms.time) - map(p - float3(0.01,0,0), uniforms.time),
            map(p + float3(0,0.01,0), uniforms.time) - map(p - float3(0,0.01,0), uniforms.time),
            map(p + float3(0,0,0.01), uniforms.time) - map(p - float3(0,0,0.01), uniforms.time)
        ));
        
        float3 lp = float3(2, 5, -3);
        float diff = max(dot(n, normalize(lp-p)), 0.0);
        
        // Checkerboard floor
        if (p.y < -0.45) {
            float checker = mod(floor(p.x * 2.0) + floor(p.z * 2.0), 2.0);
            color = mix(float3(0.1), float3(0.8), checker);
        } else {
            // Pieces
            float pieceType = p.x < 0.0 ? 0.0 : 1.0;
            color = pieceType > 0.5 ? float3(0.9) : float3(0.1, 0.05, 0.02);
        }
        
        color *= (diff + 0.3);
    }
    
    // Add bloom-like glow
    color += float3(0.1, 0.1, 0.2) * (1.0 - length(uv));
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}