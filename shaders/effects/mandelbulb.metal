#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Mandelbulb 3D Fractal

// Power function for mandelbulb
float3 powBulb(float3 v, float p) {
    float r = length(v);
    float theta = atan2(v.y, v.x);
    float phi = acos(v.z / r);
    
    float rp = pow(r, p);
    float newTheta = theta * p;
    float newPhi = phi * p;
    
    return rp * float3(
        sin(newPhi) * cos(newTheta),
        sin(newPhi) * sin(newTheta),
        cos(newPhi)
    );
}

// Distance estimator for Mandelbulb
float mandelbulbDE(float3 pos, float t, thread float4 &trap) {
    float3 z = pos;
    float dr = 1.0;
    float r = 0.0;
    float power = 8.0 + sin(t * 0.2) * 2.0;
    
    trap = float4(1.0);
    
    for (int i = 0; i < 6; i++) {
        r = length(z);
        if (r > 2.0) break;
        
        trap = min(trap, float4(abs(z), r));
        
        float theta = atan2(z.y, z.x);
        float phi = acos(z.z / r);
        
        dr = pow(r, power - 1.0) * power * dr + 1.0;
        
        float zr = pow(r, power);
        theta = theta * power;
        phi = phi * power;
        
        z = zr * float3(
            sin(phi) * cos(theta),
            sin(phi) * sin(theta),
            cos(phi)
        );
        z += pos;
    }
    
    return 0.5 * log(r) * r / dr;
}

// Scene mapping
float map(float3 p, float t, thread float4 &trap) {
    return mandelbulbDE(p, t, trap);
}

// Normal calculation
float3 calcNormal(float3 p, float t) {
    float4 trap;
    float eps = 0.001 * length(p);
    return normalize(float3(
        map(p + float3(eps, 0, 0), t, trap) - map(p - float3(eps, 0, 0), t, trap),
        map(p + float3(0, eps, 0), t, trap) - map(p - float3(0, eps, 0), t, trap),
        map(p + float3(0, 0, eps), t, trap) - map(p - float3(0, 0, eps), t, trap)
    ));
}

// Ray march
float rayMarch(float3 ro, float3 rd, float t, thread float4 &trap) {
    float dist = 0.0;
    
    for (int i = 0; i < 128; i++) {
        float3 p = ro + dist * rd;
        float radius = map(p, t, trap);
        
        if (radius < 0.001) return dist;
        if (dist > 20.0) break;
        
        float stepSize = max(radius * 0.9, 0.001);
        dist += stepSize;
    }
    
    return -1.0;
}

// Soft shadows
float softShadow(float3 ro, float3 rd, float t, float k) {
    float res = 1.0;
    float dist = 0.1;
    float4 trap;
    
    for (int i = 0; i < 32; i++) {
        if (dist > 5.0) break;
        float h = map(ro + rd * dist, t, trap);
        if (h < 0.001) return 0.0;
        res = min(res, k * h / dist);
        dist += h;
    }
    
    return res;
}

// Ambient occlusion
float calcAO(float3 p, float3 n, float t) {
    float occ = 0.0;
    float sca = 1.0;
    float4 trap;
    
    for (int i = 0; i < 5; i++) {
        float h = 0.001 + 0.15 * float(i) / 4.0;
        float d = map(p + h * n, t, trap);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 centered = in.texCoord * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed * 0.15;
    float radius = 2.5 + sin(uniforms.time * 0.1) * 0.3;
    
    float3 ro = float3(
        cos(t) * radius,
        sin(t * 0.3) * 0.3,
        sin(t) * radius
    );
    float3 ta = float3(0.0, 0.0, 0.0);
    
    float3 ww = normalize(ta - ro);
    float3 uu = normalize(cross(ww, float3(0, 1, 0)));
    float3 vv = cross(uu, ww);
    
    float2 q = centered * (1.0 + length(centered) * 0.1);
    float3 rd = normalize(q.x * uu + q.y * vv + 1.8 * ww);
    
    float4 trap;
    float dist = rayMarch(ro, rd, uniforms.time, trap);
    
    float3 col = float3(0.01, 0.02, 0.05);
    
    float star = pow(hash(in.texCoord.x * 100.0 + in.texCoord.y * 57.0), 50.0) * 0.8;
    col += float3(star);
    
    if (dist > 0.0) {
        float3 pos = ro + dist * rd;
        float3 nor = calcNormal(pos, uniforms.time);
        
        float3 light1 = normalize(float3(1.0, 0.8, 0.5));
        float3 light2 = normalize(float3(-0.5, 0.3, -0.8));
        
        float dif1 = max(dot(nor, light1), 0.0);
        float dif2 = max(dot(nor, light2), 0.0) * 0.5;
        
        float shad1 = softShadow(pos + nor * 0.001, light1, uniforms.time, 8.0);
        
        float ao = calcAO(pos, nor, uniforms.time);
        
        float fre = pow(1.0 - max(dot(nor, -rd), 0.0), 4.0);
        
        float hue = trap.w * 0.1 + uniforms.time * 0.05;
        float3 baseColor = hsv2rgb(float3(hue, 0.7 + trap.y * 0.3, 0.5 + trap.z * 0.5));
        
        float3 glowColor = hsv2rgb(float3(trap.x * 0.2 + 0.6, 0.8, 1.0));
        
        float3 lin = float3(0.0);
        lin += baseColor * dif1 * shad1 * float3(1.0, 0.9, 0.8);
        lin += baseColor * dif2 * 0.5;
        lin += baseColor * 0.3 * ao;
        lin += glowColor * fre * 0.5 * ao;
        lin += glowColor * trap.w * 0.2;
        
        col = lin;
        
        float fog = exp(-dist * 0.1);
        col = mix(float3(0.01, 0.02, 0.05), col, fog);
    }
    
    col = col / (1.0 + col);
    col = pow(col, float3(0.4545));
    col *= 1.0 - length(centered) * 0.25;
    col = mix(col, col * float3(1.0, 0.95, 0.9), 0.3);
    
    return float4(col * uniforms.intensity, uniforms.alpha);
}
