#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;
using namespace ShaderUtils;

inline float sdCircle(float2 p, float r) {
    return length(p) - r;
}

inline float sdBox2D(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

inline float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

inline float fillSDF(float d, float blur) {
    return 1.0 - smoothstep(-blur, blur, d);
}

inline float skullSDF(float2 q) {
    float head = length(q) - 0.12;
    float jaw = sdBox2D(q - float2(0.0, -0.06), float2(0.08, 0.04));
    float d = min(head, jaw);
    float eyeL = length(q - float2(-0.04, 0.02)) - 0.03;
    float eyeR = length(q - float2(0.04, 0.02)) - 0.03;
    d = max(d, -eyeL);
    d = max(d, -eyeR);
    float nose = sdBox2D(q - float2(0.0, -0.02), float2(0.015, 0.02));
    d = max(d, -nose);
    return d;
}

inline float planeSDF(float2 q) {
    float fus = sdBox2D(q, float2(0.25, 0.05));
    float wingL = sdBox2D(q - float2(-0.05, 0.0), float2(0.12, 0.02));
    float wingR = sdBox2D(q - float2(0.05, 0.0), float2(0.12, 0.02));
    float tail = sdBox2D(q - float2(-0.22, 0.08), float2(0.04, 0.06));
    return min(min(min(fus, wingL), wingR), tail);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;

    float t = fmod(uniforms.time * uniforms.speed, 3600.0);

    float2 p = centered;
    float3 color = mix(float3(0.15, 0.12, 0.2), float3(0.05, 0.05, 0.12), uv.y);

    float r = length(p);
    float ang = atan2(p.y, p.x);
    float spiral = 0.5 + 0.5 * sin(ang * 4.0 - r * 10.0 + t * 3.0);
    float funnel = smoothstep(0.9, 0.0, r) * (0.4 + 0.6 * spiral);
    color += float3(0.25, 0.28, 0.35) * funnel * 0.5;

    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float a = t * (0.6 + fi * 0.1) + fi * 2.1;
        float rad = 0.3 + fi * 0.08;
        float2 skPos = float2(cos(a), sin(a)) * rad * (0.6 + 0.4 * sin(t + fi));
        skPos += float2(sin(t * 0.7 + fi) * 0.1, cos(t * 0.5 + fi) * 0.05);
        float2 q = (p - skPos);
        q = rot(t * 1.2 + fi) * q;
        float d = skullSDF(q * 4.0) / 4.0;
        float fill = fillSDF(d, 0.01);
        color = mix(color, float3(0.9, 0.9, 0.85), fill * 0.9);
        float eye = fillSDF(length(q * 4.0 - float2(-0.16, 0.08)) - 0.12, 0.01) +
                    fillSDF(length(q * 4.0 - float2(0.16, 0.08)) - 0.12, 0.01);
        color *= (1.0 - eye * 0.6);
    }

    float2 planePos = float2(-0.6 + sin(t * 0.3) * 0.1, 0.3 + cos(t * 0.4) * 0.05);
    {
        float2 q = p - (planePos + float2(-0.15, 0.0));
        q = rot(0.3 + t * 0.2) * q;
        float d = planeSDF(q);
        float fill = fillSDF(d, 0.01);
        color = mix(color, float3(0.7, 0.75, 0.8), fill * 0.8);
    }
    {
        float2 q = p - (planePos + float2(0.1, -0.12));
        q = rot(-0.6 + t * 0.35) * q;
        float d = sdBox2D(q, float2(0.12, 0.02));
        float fill = fillSDF(d, 0.01);
        color = mix(color, float3(0.6, 0.65, 0.7), fill * 0.7);
    }
    {
        float2 q = p - (planePos + float2(-0.25, 0.12));
        q = rot(1.0 - t * 0.25) * q;
        float d = sdBox2D(q, float2(0.04, 0.06));
        float fill = fillSDF(d, 0.01);
        color = mix(color, float3(0.55, 0.6, 0.65), fill * 0.7);
    }

    {
        float2 q = p;
        q = rot(-t * 1.5) * q;
        float head = sdCircle(q, 0.22);
        float face = fillSDF(head, 0.01);
        color = mix(color, float3(1.0, 0.85, 0.1), face);
        float eyeL = sdCircle(q - float2(-0.07, 0.05), 0.035);
        float eyeR = sdCircle(q - float2(0.07, 0.05), 0.035);
        float eyes = fillSDF(eyeL, 0.01) + fillSDF(eyeR, 0.01);
        color = mix(color, float3(0.0), eyes * 0.8);
        float smileCurve = length(float2(q.x, q.y + 0.05 + q.x * q.x * 0.8)) - 0.12;
        float smileFill = fillSDF(abs(smileCurve) - 0.015, 0.01);
        if (q.y < 0.0) color = mix(color, float3(0.0), smileFill * 0.8);
    }

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return float4(color, uniforms.alpha);
}