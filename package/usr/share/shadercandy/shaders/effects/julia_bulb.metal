#include "ShaderInterop.h"

// Julia Bulb Fractal - 3D quaternion Julia set

using namespace metal;

float juliaBulb(float3 pos, float4 c) {
    float3 z = pos;
    float dr = 1.0;
    float r = 0.0;
    int iterations = 8;
    float power = 6.0 + 2.0 * sin(z.x * 0.5);
    
    for(int i = 0; i < iterations; i++) {
        r = length(z);
        if(r > 4.0) break;
        
        // Convert to spherical
        float theta = acos(z.z / r);
        float phi = atan2(z.y, z.x);
        dr = pow(r, power - 1.0) * power * dr + 1.0;
        
        // Scale and rotate
        float zr = pow(r, power);
        theta = theta * power;
        phi = phi * power;
        
        // Convert back
        z = zr * float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
        z += c.xyz;
    }
    
    return 0.5 * log(r) * r / dr;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 3.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.15;
    
    // Animated Julia parameter
    float4 c = float4(
        0.4 * sin(t * 0.3),
        0.4 * cos(t * 0.25),
        0.4 * sin(t * 0.35),
        0.0
    );
    
    // Camera
    float3 ro = float3(2.5 * sin(t * 0.2), 1.5 * cos(t * 0.15), -2.5 * cos(t * 0.2));
    float3 rd = normalize(float3(p, 1.5));
    
    // Rotate
    float c2 = cos(t * 0.1), s2 = sin(t * 0.1);
    rd.xz = float2(rd.x * c2 - rd.z * s2, rd.x * s2 + rd.z * c2);
    
    float3 col = float3(0.0);
    float dist = 0.0;
    
    for(int i = 0; i < 64; i++) {
        float3 p3 = ro + rd * dist;
        float d = juliaBulb(p3, c);
        
        if(d < 0.001) {
            float glow = exp(-d * 10.0);
            col += float3(
                0.5 + 0.5 * sin(p3.x * 4.0 + t * 2.0),
                0.5 + 0.5 * sin(p3.y * 4.0 + t * 2.0 + 2.0),
                0.5 + 0.5 * sin(p3.z * 4.0 + t * 2.0 + 4.0)
            ) * glow * 0.2;
            break;
        }
        
        dist += d * 0.7;
        if(dist > 5.0) break;
    }
    
    // Glow
    col += float3(0.15, 0.05, 0.25) * exp(-dist * 0.3);
    
    col = pow(col, float3(0.8));
    
    return float4(col * u.intensity, 1.0);
}
