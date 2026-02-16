// Fallout 3D - Vault-Tec Terminal V2
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float sdCylinder(float3 p, float2 h) {
    float2 d = abs(float2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float map(float3 p, float time) {
    // Monitor casing - curved front
    float d = sdBox(p, float3(1.0, 0.8, 0.5));
    // Bezel
    float bezel = sdBox(p - float3(0,0,-0.4), float3(0.85, 0.65, 0.1));
    d = min(d, bezel);
    
    // Stand
    float stand = sdCylinder(p - float3(0, -0.9, 0), float2(0.3, 0.1));
    d = min(d, stand);
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float3 ro = float3(0.2 * sin(uniforms.time * 0.5), 0, -2.2);
    float3 rd = normalize(float3(uv, 1.8));
    
    float t = 0.0;
    for(int i=0; i<64; i++) {
        float d = map(ro + rd*t, uniforms.time);
        if(d < 0.001 || t > 10.0) break;
        t += d;
    }
    
    float3 color = float3(0.02, 0.04, 0.02); // Fallback green
    
    if(t < 10.0) {
        float3 p = ro + rd * t;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), uniforms.time) - map(p - float3(0.01,0,0), uniforms.time),
            map(p + float3(0,0.01,0), uniforms.time) - map(p - float3(0,0.01,0), uniforms.time),
            map(p + float3(0,0,0.01), uniforms.time) - map(p - float3(0,0,0.01), uniforms.time)
        ));
        
        float3 lp = float3(1, 2, -2);
        float diff = max(dot(n, normalize(lp-p)), 0.0);
        
        // Casing color (rusty metal / plastic)
        color = float3(0.25, 0.28, 0.25) * (diff + 0.1);
        
        // If we hit the screen face
        if(p.z < -0.38 && abs(p.x) < 0.8 && abs(p.y) < 0.6) {
            float2 suv = (p.xy + float2(0.8, 0.6)) / float2(1.6, 1.2);
            
            // Screen curviness simulation
            float curv = 1.0 - length(suv - 0.5) * 0.2;
            
            // Scanlines
            float scan = sin(suv.y * 400.0 + uniforms.time * 10.0) * 0.1 + 0.9;
            
            // Fallout green text / logo
            float text = stepped_noise(float3(suv * float2(30.0, 50.0), uniforms.time * 0.05));
            float3 screenBase = float3(0.0, 1.0, 0.3);
            
            // Simplistic Vault-Tec Logo (Circle with lightning / cog)
            float distToCenter = length(suv - 0.5);
            float logo = smoothstep(0.15, 0.14, distToCenter);
            logo *= (0.5 + 0.5 * sin(atan2(suv.y-0.5, suv.x-0.5) * 8.0));
            
            float3 screenCol = screenBase * (text * 0.5 + logo * 0.8 + 0.1) * scan * curv;
            
            // Screen flicker
            screenCol *= (0.95 + 0.05 * sin(uniforms.time * 60.0));
            
            color = mix(color, screenCol, 0.9);
            // Bloom / Glow
            color += screenCol * 0.3;
        }
    } else {
        // Radioactive wasteland background glow
        color = float3(0.1, 0.12, 0.0) * (1.0 - length(uv) * 0.5);
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
