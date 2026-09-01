#include "ShaderInterop.h"

// Pastel Unicorns - Dreamy pastel color shifts, flying rainbows, and unicorns

using namespace metal;
using namespace ShaderUtils;

// Pastel palette - soft dreamy colors
float3 pastelRainbow(float t) {
    float3 c;
    c.r = 0.5 + 0.3 * sin(t);
    c.g = 0.5 + 0.3 * sin(t + 2.094);
    c.b = 0.5 + 0.3 * sin(t + 4.188);
    return c;
}

// Soft pastel palette index
float3 pastelColor(float i) {
    float3 colors[8] = {
        float3(0.95, 0.60, 0.70),  // Rose
        float3(0.70, 0.80, 0.95),  // Baby blue
        float3(0.80, 0.95, 0.75),  // Mint
        float3(0.95, 0.85, 0.65),  // Peach
        float3(0.85, 0.70, 0.95),  // Lavender
        float3(0.95, 0.75, 0.85),  // Pink
        float3(0.75, 0.90, 0.95),  // Sky
        float3(0.90, 0.95, 0.70)   // Lemon
    };
    int idx = int(i) % 8;
    return colors[idx];
}

// SDF: unicorn body (rounded cone shape)
float sdUnicornBody(float2 p) {
    // Main body - tilted ellipse
    float body = length(p * float2(1.0, 1.8)) - 0.3;
    return body;
}

// SDF: unicorn horn (spiral cone)
float sdUnicornHorn(float2 p) {
    // Cone
    float horn = p.x - (0.5 - p.y) * 0.15;
    float cap = max(-p.y, p.y - 0.4);
    return max(horn, cap);
}

// SDF: unicorn head
float sdUnicornHead(float2 p) {
    return length(p * float2(1.2, 1.0)) - 0.18;
}

// SDF: complete unicorn silhouette
float sdUnicorn(float2 p, float time) {
    // Leg animation
    float legAnim = sin(time * 4.0 + p.x * 3.0) * 0.05;

    // Body
    float body = sdUnicornBody(p - float2(0.0, 0.0));

    // Head (offset from body)
    float head = sdUnicornHead(p - float2(0.25, 0.25));

    // Horn
    float horn = sdUnicornHorn(p - float2(0.35, 0.38));

    // Legs (simple cylinders)
    float legs = 1e10;
    float2 legPositions[4] = {
        float2(-0.15, -0.35), float2(-0.05, -0.35),
        float2(0.05, -0.35), float2(0.15, -0.35)
    };
    for (int i = 0; i < 4; i++) {
        float2 lp = p - legPositions[i];
        lp.y += legAnim * float(i % 2 == 0 ? 1.0 : -1.0);
        legs = min(legs, length(lp) - 0.04);
    }

    // Combine all parts
    float unicorn = min(body, head);
    unicorn = min(unicorn, legs);
    unicorn = max(unicorn, -horn); // Cut out horn from body

    return unicorn;
}

// Sparkle/star field
float sparkle(float2 uv, float time) {
    float s = 0.0;
    for (int i = 0; i < 3; i++) {
        float2 grid = floor(uv * (20.0 + float(i) * 10.0));
        float h = hash(grid.x + grid.y * 57.0 + float(i) * 113.0);
        if (h > 0.97) {
            float2 center = (grid + 0.5) / (20.0 + float(i) * 10.0);
            float d = length(uv - center);
            float twinkle = sin(time * 3.0 + h * 20.0) * 0.5 + 0.5;
            s += twinkle * smoothstep(0.02, 0.0, d) * (1.0 - float(i) * 0.2);
        }
    }
    return s;
}

// Flying rainbow arc
float3 rainbowArc(float2 uv, float time, float offset) {
    float t = time * 0.3 + offset;
    float2 center = float2(
        sin(t * 0.7) * 0.3,
        cos(t * 0.5) * 0.2 + 0.1
    );
    float radius = 0.5 + sin(t * 0.3) * 0.1;
    float arcWidth = 0.03 + sin(t * 2.0) * 0.01;

    float d = abs(length(uv - center) - radius);
    float arc = smoothstep(arcWidth, 0.0, d);

    // Rainbow colors along the arc
    float angle = atan2(uv.y - center.y, uv.x - center.x);
    float3 col = pastelRainbow(angle * 2.0 + time);

    return col * arc * 0.6;
}

// Sparkle trail behind unicorn
float3 sparkleTrail(float2 uv, float time) {
    float3 col = float3(0.0);
    float speed = 2.0;

    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        float trailTime = time - fi * 0.08;
        float2 pos = float2(
            sin(trailTime * speed + fi * 0.5) * 0.3,
            cos(trailTime * speed * 0.7 + fi * 0.3) * 0.25
        );

        float d = length(uv - pos);
        float brightness = (1.0 - fi / 12.0) * smoothstep(0.1, 0.0, d);
        float3 sparkleCol = pastelColor(fi * 0.7 + time);

        col += sparkleCol * brightness;
    }

    return col;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;

    float t = uniforms.time * uniforms.speed;

    // Background: soft pastel gradient
    float3 bg = mix(
        float3(0.15, 0.10, 0.20),
        float3(0.25, 0.15, 0.30),
        uv.y
    );
    bg += float3(0.05, 0.02, 0.08) * sin(t * 0.2 + uv.x * 3.0);

    // Animated pastel color shifts
    float3 colorShift = pastelRainbow(t * 0.3);
    bg = mix(bg, bg + colorShift * 0.15, 0.5);

    float3 col = bg;

    // Flying rainbows
    col += rainbowArc(centered, t, 0.0);
    col += rainbowArc(centered, t, 2.094);
    col += rainbowArc(centered, t, 4.188);

    // Sparkle trail
    col += sparkleTrail(centered, t);

    // Unicorn - multiple at different positions
    float2 unicornPos1 = float2(
        sin(t * 0.5) * 0.4,
        cos(t * 0.3) * 0.3 + 0.05
    );
    float2 unicornPos2 = float2(
        sin(t * 0.4 + 2.0) * 0.35,
        cos(t * 0.35 + 1.0) * 0.25 + 0.1
    );

    float d1 = sdUnicorn(centered - unicornPos1, t);
    float d2 = sdUnicorn((centered - unicornPos2) * float2(-1.0, 1.0), t + 1.0);

    // Unicorn colors - pastel rainbow body
    float3 uniCol1 = pastelRainbow(t * 0.5 + length(unicornPos1));
    float3 uniCol2 = pastelRainbow(t * 0.5 + length(unicornPos2) + 1.0);

    // Render unicorns with soft edges
    float edge1 = smoothstep(0.02, -0.01, d1);
    float edge2 = smoothstep(0.02, -0.01, d2);

    // Horn glow
    float hornD1 = sdUnicornHorn(centered - unicornPos1 - float2(0.35, 0.38));
    float hornD2 = sdUnicornHorn((centered - unicornPos2) * float2(-1.0, 1.0) - float2(0.35, 0.38));
    float hornGlow1 = exp(-hornD1 * 8.0) * 0.8;
    float hornGlow2 = exp(-hornD2 * 8.0) * 0.8;

    col = mix(col, uniCol1 * 1.2, edge1 * 0.8);
    col = mix(col, uniCol2 * 1.2, edge2 * 0.8);
    col += float3(1.0, 0.95, 0.8) * hornGlow1;
    col += float3(0.95, 0.9, 1.0) * hornGlow2;

    // Sparkle field
    col += float3(1.0, 0.98, 0.95) * sparkle(uv, t) * 0.4;

    // Pastel vignette
    float vig = 1.0 - length(centered) * 0.3;
    col *= vig;

    // Tone mapping
    col = col / (1.0 + col);
    col = pow(col, float3(0.9));

    return float4(col * uniforms.intensity, uniforms.alpha);
}
