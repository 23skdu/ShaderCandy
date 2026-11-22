#include "base/common.glsl"

// fractal_clockwork - Steampunk clockwork with rotating gears and fractal escapement

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = vec3(0.08, 0.06, 0.04);

    float gearSpeed = 0.5 + volume * 0.5 * intensity;

    // Background brass gradient
    color = mix(vec3(0.12, 0.09, 0.05), vec3(0.25, 0.18, 0.1), uv.y);

    // Large central gear
    float r = length(p);
    float angle = atan(p.y, p.x);
    float gear1 = abs(sin(angle * 12.0 + t * gearSpeed)) * 0.05;
    float d1 = r - (0.5 + gear1);
    float gearFill1 = fillSDF(d1, 0.01);
    // Teeth
    float teeth1 = step(0.48, r) * step(r, 0.55) * step(0.5, abs(sin(angle * 12.0 + t * gearSpeed)));
    color += vec3(0.8, 0.6, 0.2) * gearFill1 * 0.7;
    color += vec3(0.9, 0.75, 0.3) * teeth1 * 0.5;

    // Hub
    float hub = fillSDF(r - 0.12, 0.01);
    color = mix(color, vec3(0.3, 0.2, 0.1), hub);

    // Second smaller gear
    vec2 g2Pos = vec2(0.7, 0.2);
    vec2 q2 = p - g2Pos;
    float r2 = length(q2);
    float a2 = atan(q2.y, q2.x);
    float gear2Fill = fillSDF(r2 - 0.22, 0.01);
    float teeth2 = step(0.18, r2) * step(r2, 0.26) * step(0.5, abs(sin(a2 * 8.0 - t * gearSpeed * 1.5)));
    color += vec3(0.7, 0.5, 0.15) * gear2Fill * 0.6;
    color += vec3(0.85, 0.7, 0.3) * teeth2 * 0.4;

    // Fractal escapement (recursive subdivision, capped at 4)
    vec2 ep = p * 1.5;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        ep = abs(ep) - vec2(0.3 - fi * 0.05);
        ep = rot(t * gearSpeed * 0.2 + fi) * ep;
        float d = length(ep) - 0.05;
        float f = fillSDF(d, 0.005);
        color += vec3(0.95, 0.85, 0.5) * f * (0.3 / (fi + 1.0));
    }

    // Vignette
    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return vec4(color, 1.0);
}