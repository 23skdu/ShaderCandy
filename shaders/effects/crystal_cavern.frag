#include "base/common.glsl"

// crystal_cavern - Glowing crystal formations in a dark cave with caustic light

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = vec3(0.02, 0.03, 0.08);

    // Caustic light shafts
    float caustic = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        caustic += sin(p.x * (6.0 + fi) + t * (0.4 + fi * 0.2)) *
                   sin(p.y * (5.0 + fi) - t * (0.3 + fi * 0.15));
    }
    caustic = 0.5 + 0.5 * caustic / 3.0;
    color += vec3(0.1, 0.2, 0.35) * caustic * 0.4;

    // Flashlight from mouse
    vec2 lightPos = mouse * 2.0 - 1.0;
    lightPos.x *= resolution.x / resolution.y;
    float lightDist = length(p - lightPos);
    float light = exp(-lightDist * 1.5) * 0.6;
    color += vec3(0.9, 0.95, 1.0) * light;

    // Crystals
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        vec2 cPos = vec2(sin(fi * 1.7 + t * 0.1) * 0.6, -0.3 + fi * 0.15);
        float rotA = fi * 0.8 + t * 0.05;
        mat2 r = rot(rotA);
        vec2 q = r * (p - cPos);
        float d = sdBox2D(q, vec2(0.05, 0.18 + fi * 0.03));
        float fill = fillSDF(d, 0.01);
        vec3 crystalCol = mix(vec3(0.2, 0.5, 0.9), vec3(0.8, 0.3, 1.0), fi / 6.0);
        crystalCol *= 1.0 + treble * 0.5 * intensity;
        // Emissive tip
        float tip = smoothstep(0.02, 0.0, length(q - vec2(0.0, 0.18 + fi * 0.03)));
        color += crystalCol * fill + vec3(1.0, 0.9, 1.0) * tip * 0.5;
    }

    // Vignette
    color *= 1.0 - smoothstep(0.6, 1.4, length(p));

    return vec4(color, 1.0);
}