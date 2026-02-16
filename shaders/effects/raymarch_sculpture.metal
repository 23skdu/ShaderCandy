#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Ray March Sculpture - Abstract geometric sculpture

// Scene mapping
float map(float3 p, float t) {
    float3 q = rotateY(p, t);
    q = rotateX(q, t * 0.5);
    
    float d1 = sdSphere(q, 1.5);
    
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * TWO_PI / 6.0 + t;
        float3 holePos = float3(cos(angle), sin(angle * 0.5), sin(angle)) * 0.8;
        d1 = opSubtraction(sdSphere(q - holePos, 0.4), d1);
    }
    
    float3 q2 = rotateZ(p, t * 0.7);
    q2 = rotateY(q2, t * 0.3);
    float d2 = sdTorus(q2, float2(2.2, 0.15));
    
    float d3 = sdTorus(rotateX(p, t * 0.5 + PI/3.0), float2(2.0, 0.1));
    
    float d = opSmoothUnion(d1, d2, 0.2);
    d = opSmoothUnion(d, d3, 0.15);
    
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float3 particlePos = float3(
            sin(t * 0.5 + fi) * (2.5 + fi * 0.3),
            cos(t * 0.3 + fi * 1.3) * (2.0 + fi * 0.2),
            sin(t * 0.4 + fi * 0.7) * (2.5 + fi * 0.3)
        );
        d = opSmoothUnion(d, sdSphere(p - particlePos, 0.1 + fi * 0.05), 0.1);
    }
    
    return d;
}

// Calculate normal
float3 calcNormal(float3 p, float t) {
    float eps = 0.001;
    return normalize(float3(
        map(p + float3(eps, 0, 0), t) - map(p - float3(eps, 0, 0), t),
        map(p + float3(0, eps, 0), t) - map(p - float3(0, eps, 0), t),
        map(p + float3(0, 0, eps), t) - map(p - float3(0, 0, eps), t)
    ));
}

// Ray march
float rayMarch(float3 ro, float3 rd, float t) {
    float dist = 0.0;
    for (int i = 0; i < 100; i++) {
        float3 p = ro + dist * rd;
        float d = map(p, t);
        if (d < 0.001 || dist > 50.0) break;
        dist += d;
    }
    return dist;
}

// Soft shadow
float softShadow(float3 ro, float3 rd, float t, float k) {
    float res = 1.0;
    float dist = 0.1;
    
    for (int i = 0; i < 32; i++) {
        float h = map(ro + rd * dist, t);
        res = min(res, k * h / dist);
        dist += clamp(h, 0.01, 0.5);
        if (res < 0.001 || dist > 20.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

// Ambient occlusion
float calcAO(float3 p, float3 n, float t) {
    float occ = 0.0;
    float sca = 1.0;
    
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = map(p + h * n, t);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 centered = in.texCoord * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed * 0.2;
    float3 ro = float3(
        sin(t) * 4.0,
        sin(t * 0.5) * 1.0 + 0.5,
        cos(t) * 4.0
    );
    float3 ta = float3(0.0, 0.0, 0.0);
    
    float3 ww = normalize(ta - ro);
    float3 uu = normalize(cross(ww, float3(0, 1, 0)));
    float3 vv = cross(uu, ww);
    
    float3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    float dist = rayMarch(ro, rd, t);
    
    float3 col = float3(0.02, 0.02, 0.05);
    
    if (dist < 50.0) {
        float3 pos = ro + dist * rd;
        float3 nor = calcNormal(pos, t);
        
        float3 lightPos = float3(5.0, 8.0, 5.0);
        float3 lig = normalize(lightPos - pos);
        
        float dif = max(dot(nor, lig), 0.0);
        
        float3 ref = reflect(-lig, nor);
        float spec = pow(max(dot(ref, -rd), 0.0), 32.0);
        
        float shad = softShadow(pos + nor * 0.01, lig, t, 8.0);
        
        float ao = calcAO(pos, nor, t);
        
        float fre = pow(1.0 - max(dot(nor, -rd), 0.0), 3.0);
        
        float hue = length(pos) * 0.2 + uniforms.time * 0.1;
        float3 matCol = hsv2rgb(float3(fract(hue), 0.8, 1.0));
        
        col = matCol * dif * shad;
        col += float3(0.5) * spec * shad;
        col += matCol * fre * 0.5;
        col *= ao;
        
        float fog = exp(-dist * 0.05);
        col = mix(float3(0.02, 0.02, 0.05), col, fog);
    }
    
    col = pow(col, float3(0.4545));
    col *= 1.0 - length(centered) * 0.3;
    
    return float4(col * uniforms.intensity, uniforms.alpha);
}
