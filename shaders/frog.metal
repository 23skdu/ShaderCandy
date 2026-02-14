// Frog 3D - Pond Life
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;



float sdEllipsoid(float3 p, float3 r) {
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
}

float map(float3 p, float time) {
    // Water surface
    float water = p.y + 0.5 + 0.05 * sin(p.x * 4.0 + time) * cos(p.z * 4.0 + time);
    
    // Lily pad
    float2 lp_pos = float2(0,0);
    float pad = length(p.xz - lp_pos) - 1.2;
    pad = max(pad, abs(p.y + 0.4) - 0.05);
    // Notch in lily pad
    float notch = length(p.xz - lp_pos - float2(1.0, 0.0)) - 0.5;
    pad = max(pad, -notch);
    
    // Frog body (simplified)
    float3 fp = p - float3(0.0, -0.1, 0.0);
    float body = sdEllipsoid(fp, float3(0.4, 0.3, 0.5));
    
    // Eyes
    float eyeL = sdSphere(fp - float3(-0.2, 0.2, 0.3), 0.15);
    float eyeR = sdSphere(fp - float3(0.2, 0.2, 0.3), 0.15);
    
    float d = min(water, pad);
    d = min(d, body);
    d = min(d, min(eyeL, eyeR));
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    float3 ro = float3(2.5 * sin(t*0.2), 1.5, -3.5);
    float3 rd = normalize(float3(uv, 1.2));
    rd = lookAt(ro, float3(0,0,0)) * rd;
    
    float dTotal = 0.0;
    for(int i=0; i<80; i++) {
        float d = map(ro + rd*dTotal, t);
        if(d < 0.001 || dTotal > 20.0) break;
        dTotal += d;
    }
    
    float3 color = float3(0.01, 0.05, 0.1); // Deep water
    
    if(dTotal < 20.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        float3 lp = float3(2.0, 4.0, -2.0);
        float diff = max(dot(n, normalize(lp-p)), 0.0);
        
        // Coloring
        if(p.y < -0.42) {
            // Water
            color = float3(0.1, 0.4, 0.6) * (diff + 0.2);
            // Ripple highlights
            color += float3(0.5, 0.8, 1.0) * pow(max(dot(reflect(-normalize(lp-p), n), -rd), 0.0), 32.0);
        } else if(length(p.xz) < 1.3 && p.y < -0.3) {
            // Lily pad
            color = float3(0.1, 0.5, 0.1) * (diff + 0.1);
        } else {
            // Frog
            float3 frogCol = float3(0.4, 0.8, 0.2);
            // Eyes
            if(p.y > 0.0) {
                float pupil = smoothstep(0.05, 0.04, length(p.xy - float2(p.x > 0 ? 0.2 : -0.2, 0.2)));
                frogCol = mix(frogCol, float3(0.0), pupil);
            }
            color = frogCol * (diff + 0.1);
        }
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}