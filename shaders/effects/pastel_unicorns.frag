#version 450 core

#include "base/common.glsl"

// Pastel Unicorns - Dreamy pastel color shifts, flying rainbows, and unicorns

vec3 pastelRainbow(float t) {
    return vec3(
        0.5 + 0.3 * sin(t),
        0.5 + 0.3 * sin(t + 2.094),
        0.5 + 0.3 * sin(t + 4.188)
    );
}

vec3 pastelColor(float i) {
    vec3 colors[8] = vec3[8](
        vec3(0.95, 0.60, 0.70),
        vec3(0.70, 0.80, 0.95),
        vec3(0.80, 0.95, 0.75),
        vec3(0.95, 0.85, 0.65),
        vec3(0.85, 0.70, 0.95),
        vec3(0.95, 0.75, 0.85),
        vec3(0.75, 0.90, 0.95),
        vec3(0.90, 0.95, 0.70)
    );
    int idx = int(i) % 8;
    return colors[idx];
}

float sdUnicornBody(vec2 p) {
    return length(p * vec2(1.0, 1.8)) - 0.3;
}

float sdUnicornHorn(vec2 p) {
    float horn = p.x - (0.5 - p.y) * 0.15;
    float cap = max(-p.y, p.y - 0.4);
    return max(horn, cap);
}

float sdUnicornHead(vec2 p) {
    return length(p * vec2(1.2, 1.0)) - 0.18;
}

float sdUnicorn(vec2 p, float time) {
    float legAnim = sin(time * 4.0 + p.x * 3.0) * 0.05;
    float body = sdUnicornBody(p - vec2(0.0, 0.0));
    float head = sdUnicornHead(p - vec2(0.25, 0.25));
    float horn = sdUnicornHorn(p - vec2(0.35, 0.38));

    float legs = 1e10;
    vec2 legPos0 = vec2(-0.15, -0.35);
    vec2 legPos1 = vec2(-0.05, -0.35);
    vec2 legPos2 = vec2(0.05, -0.35);
    vec2 legPos3 = vec2(0.15, -0.35);

    vec2 lp0 = p - legPos0;
    lp0.y += legAnim;
    legs = min(legs, length(lp0) - 0.04);

    vec2 lp1 = p - legPos1;
    lp1.y -= legAnim;
    legs = min(legs, length(lp1) - 0.04);

    vec2 lp2 = p - legPos2;
    lp2.y += legAnim;
    legs = min(legs, length(lp2) - 0.04);

    vec2 lp3 = p - legPos3;
    lp3.y -= legAnim;
    legs = min(legs, length(lp3) - 0.04);

    float unicorn = min(body, head);
    unicorn = min(unicorn, legs);
    unicorn = max(unicorn, -horn);

    return unicorn;
}

float sparkle(vec2 uv, float time) {
    float s = 0.0;
    for (int i = 0; i < 3; i++) {
        vec2 grid = floor(uv * (20.0 + float(i) * 10.0));
        float h = hash(grid.x + grid.y * 57.0 + float(i) * 113.0);
        if (h > 0.97) {
            vec2 center = (grid + 0.5) / (20.0 + float(i) * 10.0);
            float d = length(uv - center);
            float twinkle = sin(time * 3.0 + h * 20.0) * 0.5 + 0.5;
            s += twinkle * smoothstep(0.02, 0.0, d) * (1.0 - float(i) * 0.2);
        }
    }
    return s;
}

vec3 rainbowArc(vec2 uv, float time, float offset) {
    float t = time * 0.3 + offset;
    vec2 center = vec2(
        sin(t * 0.7) * 0.3,
        cos(t * 0.5) * 0.2 + 0.1
    );
    float radius = 0.5 + sin(t * 0.3) * 0.1;
    float arcWidth = 0.03 + sin(t * 2.0) * 0.01;

    float d = abs(length(uv - center) - radius);
    float arc = smoothstep(arcWidth, 0.0, d);

    float angle = atan(uv.y - center.y, uv.x - center.x);
    vec3 col = pastelRainbow(angle * 2.0 + time);

    return col * arc * 0.6;
}

vec3 sparkleTrail(vec2 uv, float time) {
    vec3 col = vec3(0.0);
    float speed = 2.0;

    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        float trailTime = time - fi * 0.08;
        vec2 pos = vec2(
            sin(trailTime * speed + fi * 0.5) * 0.3,
            cos(trailTime * speed * 0.7 + fi * 0.3) * 0.25
        );

        float d = length(uv - pos);
        float brightness = (1.0 - fi / 12.0) * smoothstep(0.1, 0.0, d);
        vec3 sparkleCol = pastelColor(fi * 0.7 + time);

        col += sparkleCol * brightness;
    }

    return col;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;

    // Background: soft pastel gradient
    vec3 bg = mix(
        vec3(0.15, 0.10, 0.20),
        vec3(0.25, 0.15, 0.30),
        uv.y
    );
    bg += vec3(0.05, 0.02, 0.08) * sin(t * 0.2 + uv.x * 3.0);

    // Animated pastel color shifts
    vec3 colorShift = pastelRainbow(t * 0.3);
    bg = mix(bg, bg + colorShift * 0.15, 0.5);

    vec3 col = bg;

    // Flying rainbows
    col += rainbowArc(centered, t, 0.0);
    col += rainbowArc(centered, t, 2.094);
    col += rainbowArc(centered, t, 4.188);

    // Sparkle trail
    col += sparkleTrail(centered, t);

    // Unicorn 1
    vec2 unicornPos1 = vec2(
        sin(t * 0.5) * 0.4,
        cos(t * 0.3) * 0.3 + 0.05
    );
    float d1 = sdUnicorn(centered - unicornPos1, t);
    vec3 uniCol1 = pastelRainbow(t * 0.5 + length(unicornPos1));
    float edge1 = smoothstep(0.02, -0.01, d1);
    col = mix(col, uniCol1 * 1.2, edge1 * 0.8);

    // Unicorn 2 (mirrored)
    vec2 unicornPos2 = vec2(
        sin(t * 0.4 + 2.0) * 0.35,
        cos(t * 0.35 + 1.0) * 0.25 + 0.1
    );
    float d2 = sdUnicorn((centered - unicornPos2) * vec2(-1.0, 1.0), t + 1.0);
    vec3 uniCol2 = pastelRainbow(t * 0.5 + length(unicornPos2) + 1.0);
    float edge2 = smoothstep(0.02, -0.01, d2);
    col = mix(col, uniCol2 * 1.2, edge2 * 0.8);

    // Sparkle field
    col += vec3(1.0, 0.98, 0.95) * sparkle(uv, t) * 0.4;

    // Pastel vignette
    float vig = 1.0 - length(centered) * 0.3;
    col *= vig;

    // Tone mapping
    col = col / (1.0 + col);
    col = pow(col, vec3(0.9));

    col *= intensity;
    return vec4(col, alpha);
}
