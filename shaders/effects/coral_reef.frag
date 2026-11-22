#include "base/common.glsl"

// coral_reef - Underwater reef with swaying coral, fish silhouettes, and caustic shafts

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    // Underwater gradient
    vec3 color = mix(vec3(0.0, 0.15, 0.35), vec3(0.0, 0.05, 0.15), uv.y);

    // Caustic light shafts
    float caustic = 0.0;
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        caustic += sin(p.x * (8.0 + fi * 3.0) + t * 0.6 + fi) *
                   sin(p.y * (7.0 + fi * 2.0) - t * 0.5);
    }
    caustic = 0.5 + 0.5 * caustic / 2.0;
    color += vec3(0.4, 0.7, 0.9) * caustic * 0.25 * (0.6 + mid * 0.4);

    // Coral formations
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float cx = -0.8 + fi * 0.4;
        float sway = sin(t * 0.8 + fi) * 0.05;
        vec2 cPos = vec2(cx + sway, -0.7 + fi * 0.05);
        float h = 0.25 + fi * 0.08;
        vec2 q = p - cPos;
        // Simple branchy coral as vertical segments
        float d = sdSegment(q, vec2(0.0, 0.0), vec2(sway, h));
        float col = fillSDF(d, 0.015);
        vec3 coralCol = mix(vec3(0.9, 0.3, 0.4), vec3(1.0, 0.6, 0.2), fi / 5.0);
        color += coralCol * col * 0.9;
        // Tips
        float tip = smoothstep(0.02, 0.0, length(q - vec2(sway, h)));
        color += vec3(1.0, 0.9, 0.7) * tip * 0.4;
    }

    // Fish silhouettes
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float fx = mod(t * (0.15 + fi * 0.05) + fi * 0.7, 2.4) - 1.2;
        float fy = -0.2 + sin(t * 0.5 + fi) * 0.3;
        vec2 fPos = vec2(fx, fy);
        vec2 q = p - fPos;
        // Fish body as elongated circle
        float body = length(q * vec2(1.0, 2.0)) - 0.06;
        float fish = fillSDF(body, 0.01);
        color = mix(color, vec3(0.05, 0.05, 0.08), fish * 0.8);
    }

    // Bubbles
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float bx = -0.9 + fi * 0.25;
        float by = mod(t * (0.2 + mid * 0.3) + fi * 0.4, 2.0) - 1.0;
        float bubble = smoothstep(0.025, 0.02, length(p - vec2(bx, by)));
        color += vec3(0.7, 0.9, 1.0) * bubble * 0.5;
    }

    // Vignette
    color *= 1.0 - smoothstep(0.7, 1.5, length(p));

    return vec4(color, 1.0);
}