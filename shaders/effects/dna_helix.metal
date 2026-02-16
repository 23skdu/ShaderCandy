#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// DNA Double Helix - Molecular visualization

// Rotate point around axis
float3 rotateAroundAxis(float3 p, float3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0 - c;
    
    float3 a = normalize(axis);
    
    float3x3 rot = float3x3(
        t * a.x * a.x + c,        t * a.x * a.y - s * a.z,  t * a.x * a.z + s * a.y,
        t * a.x * a.y + s * a.z,  t * a.y * a.y + c,        t * a.y * a.z - s * a.x,
        t * a.x * a.z - s * a.y,  t * a.y * a.z + s * a.x,  t * a.z * a.z + c
    );
    
    return rot * p;
}

// Cylinder SDF
float sdCylinder(float3 p, float r, float h) {
    float2 d = float2(length(p.xz) - r, abs(p.y) - h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// DNA helix SDF
float sdDNA(float3 p, float t) {
    float radius = 0.3;
    float pitch = 0.8;
    
    float strand1 = 1000.0;
    float strand2 = 1000.0;
    
    float twist = p.y * pitch + t * 0.5;
    
    float3 basePos1 = float3(
        cos(twist) * radius,
        p.y,
        sin(twist) * radius
    );
    
    float3 basePos2 = float3(
        cos(twist + PI) * radius,
        p.y,
        sin(twist + PI) * radius
    );
    
    strand1 = length(p - basePos1) - 0.04;
    strand2 = length(p - basePos2) - 0.04;
    
    float rung = 1000.0;
    float rungSpacing = 0.15;
    float yOffset = mod(p.y + 100.0, rungSpacing) - rungSpacing * 0.5;
    
    if (abs(yOffset) < 0.02) {
        float3 rungPos = float3(p.x * 0.5, basePos1.y, p.z * 0.5);
        rung = sdCylinder(rungPos - float3(0.0, 0.0, 0.0), 0.015, radius * 0.9);
    }
    
    float dna = min(strand1, strand2);
    dna = min(dna, rung);
    
    return dna;
}

// Scene mapping
float map(float3 p, float t) {
    return sdDNA(p, t);
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

// Ray marching
float rayMarch(float3 ro, float3 rd, float t) {
    float d = 0.0;
    for (int i = 0; i < 100; i++) {
        float3 p = ro + rd * d;
        float dist = map(p, t);
        if (dist < 0.001 || d > 20.0) break;
        d += dist;
    }
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float t = uniforms.time * uniforms.speed * 0.3;
    
    float3 ro = float3(
        sin(t) * 1.5,
        sin(t * 0.5) * 0.5,
        cos(t) * 1.5
    );
    float3 ta = float3(0.0, 0.0, 0.0);
    
    float3 ww = normalize(ta - ro);
    float3 uu = normalize(cross(ww, float3(0, 1, 0)));
    float3 vv = cross(uu, ww);
    
    float2 centered = in.texCoord * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    float3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    float dist = rayMarch(ro, rd, uniforms.time);
    
    float3 col = float3(0.02, 0.02, 0.05);
    
    if (dist < 20.0) {
        float3 pos = ro + dist * rd;
        float3 nor = calcNormal(pos, uniforms.time);
        
        float3 light = normalize(float3(1.0, 2.0, 1.0));
        float dif = max(dot(nor, light), 0.0);
        
        float strandID = sin(pos.y * 10.0 + uniforms.time);
        float3 strandColor = mix(
            float3(0.8, 0.3, 0.2),
            float3(0.2, 0.5, 0.9),
            smoothstep(-0.5, 0.5, strandID)
        );
        
        if (abs(mod(pos.y + 100.0, 0.15) - 0.075) < 0.02) {
            strandColor = float3(0.9, 0.9, 0.3);
        }
        
        float fre = pow(1.0 - max(dot(nor, -rd), 0.0), 3.0);
        
        col = strandColor * dif * 0.8;
        col += float3(0.5) * fre;
        
        float fog = exp(-dist * 0.2);
        col = mix(float3(0.02, 0.02, 0.05), col, fog);
    }
    
    // Particles
    for (int i = 0; i < 30; i++) {
        float fi = float(i);
        float3 particlePos = float3(
            sin(fi * 0.7 + t) * (0.8 + fi * 0.02),
            cos(fi * 0.5 + t * 0.8) * 0.4,
            sin(fi * 0.3 + t * 0.6) * (0.8 + fi * 0.02)
        );
        
        float3 oc = ro - particlePos;
        float b = dot(oc, rd);
        float c = dot(oc, oc) - 0.01;
        float h = b * b - c;
        
        if (h > 0.0) {
            float d = -b - sqrt(h);
            if (d > 0.0 && d < dist) {
                float3 glowColor = hsv2rgb(float3(fi / 30.0 + t * 0.1, 0.9, 1.0));
                col += glowColor * 0.1 * (1.0 - d / dist);
            }
        }
    }
    
    col = pow(col, float3(0.4545));
    col *= 1.0 - length(centered) * 0.2;
    
    return float4(col * uniforms.intensity, uniforms.alpha);
}
