#include "base/common.glsl"

// emoji_tornado - Happy face emoji caught in a tornado tearing up a plane, with random skulls

float skullSDF(vec2 q) {
    float head = length(q) - 0.12;
    float jaw = sdBox2D(q - vec2(0.0, -0.06), vec2(0.08, 0.04));
    float d = min(head, jaw);
    float eyeL = length(q - vec2(-0.04, 0.02)) - 0.03;
    float eyeR = length(q - vec2(0.04, 0.02)) - 0.03;
    d = max(d, -eyeL);
    d = max(d, -eyeR);
    float nose = sdBox2D(q - vec2(0.0, -0.02), vec2(0.015, 0.02));
    d = max(d, -nose);
    return d;
}

float planeSDF(vec2 q) {
    // Fuselage
    float fus = sdBox2D(q, vec2(0.25, 0.05));
    // Wings
    float wingL = sdBox2D(q - vec2(-0.05, 0.0), vec2(0.12, 0.02));
    float wingR = sdBox2D(q - vec2(0.05, 0.0), vec2(0.12, 0.02));
    // Tail
    float tail = sdBox2D(q - vec2(-0.22, 0.08), vec2(0.04, 0.06));
    return min(min(min(fus, wingL), wingR), tail);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    // Stormy sky
    vec3 color = mix(vec3(0.15, 0.12, 0.2), vec3(0.05, 0.05, 0.12), uv.y);

    // Tornado funnel
    float r = length(p);
    float ang = atan(p.y, p.x);
    float spiral = 0.5 + 0.5 * sin(ang * 4.0 - r * 10.0 + t * 3.0);
    float funnel = smoothstep(0.9, 0.0, r) * (0.4 + 0.6 * spiral);
    color += vec3(0.25, 0.28, 0.35) * funnel * 0.5;

    // Flying debris skulls (random)
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float a = t * (0.6 + fi * 0.1) + fi * 2.1;
        float rad = 0.3 + fi * 0.08;
        vec2 skPos = vec2(cos(a), sin(a)) * rad * (0.6 + 0.4 * sin(t + fi));
        skPos += vec2(sin(t * 0.7 + fi) * 0.1, cos(t * 0.5 + fi) * 0.05);
        vec2 q = (p - skPos);
        // rotate skull
        q = rot(t * 1.2 + fi) * q;
        float d = skullSDF(q * 4.0) / 4.0;
        float fill = fillSDF(d, 0.01);
        color = mix(color, vec3(0.9, 0.9, 0.85), fill * 0.9);
        // eye sockets dark
        float eye = fillSDF(length(q * 4.0 - vec2(-0.16, 0.08)) - 0.12, 0.01) +
                    fillSDF(length(q * 4.0 - vec2(0.16, 0.08)) - 0.12, 0.01);
        color *= (1.0 - eye * 0.6);
    }

    // Plane being torn (broken into pieces)
    vec2 planePos = vec2(-0.6 + sin(t * 0.3) * 0.1, 0.3 + cos(t * 0.4) * 0.05);
    // Piece 1: fuselage left
    {
        vec2 q = p - (planePos + vec2(-0.15, 0.0));
        q = rot(0.3 + t * 0.2) * q;
        float d = planeSDF(q);
        float fill = fillSDF(d, 0.01);
        color = mix(color, vec3(0.7, 0.75, 0.8), fill * 0.8);
    }
    // Piece 2: wing
    {
        vec2 q = p - (planePos + vec2(0.1, -0.12));
        q = rot(-0.6 + t * 0.35) * q;
        float d = sdBox2D(q, vec2(0.12, 0.02));
        float fill = fillSDF(d, 0.01);
        color = mix(color, vec3(0.6, 0.65, 0.7), fill * 0.7);
    }
    // Piece 3: tail
    {
        vec2 q = p - (planePos + vec2(-0.25, 0.12));
        q = rot(1.0 - t * 0.25) * q;
        float d = sdBox2D(q, vec2(0.04, 0.06));
        float fill = fillSDF(d, 0.01);
        color = mix(color, vec3(0.55, 0.6, 0.65), fill * 0.7);
    }

    // Happy face emoji spinning in tornado
    {
        vec2 q = p;
        q = rot(-t * 1.5) * q;
        vec2 ePos = vec2(0.0, 0.0);
        q -= ePos;
        // Head
        float head = sdCircle(q, 0.22);
        float face = fillSDF(head, 0.01);
        color = mix(color, vec3(1.0, 0.85, 0.1), face);
        // Eyes
        float eyeL = sdCircle(q - vec2(-0.07, 0.05), 0.035);
        float eyeR = sdCircle(q - vec2(0.07, 0.05), 0.035);
        float eyes = fillSDF(eyeL, 0.01) + fillSDF(eyeR, 0.01);
        color = mix(color, vec3(0.0), eyes * 0.8);
        // Smile
        float smile = sdSegment(q, vec2(-0.1, -0.02), vec2(0.1, -0.02));
        // curve smile by offsetting y based on x^2
        float smileCurve = length(vec2(q.x, q.y + 0.05 + q.x * q.x * 0.8)) - 0.12;
        float smileFill = fillSDF(abs(smileCurve) - 0.015, 0.01);
        // Only bottom half
        if (q.y < 0.0) color = mix(color, vec3(0.0), smileFill * 0.8);
    }

    // Vignette
    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return vec4(color, 1.0);
}