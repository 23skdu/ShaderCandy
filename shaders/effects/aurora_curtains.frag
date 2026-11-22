#include "base/common.glsl"

// aurora_curtains - Flowing northern lights curtains across a starry sky

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = mix(vec3(0.0, 0.0, 0.05), vec3(0.02, 0.0, 0.12), uv.y);

    // Stars
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 sUV = p * (40.0 + fi * 30.0);
        float n = hash(floor(sUV) + fi * 17.0);
        if (n > 0.985) {
            float tw = 0.5 + 0.5 * sin(t * (1.0 + fi) + n * 20.0);
            color += vec3(0.8, 0.9, 1.0) * tw * 0.6;
        }
    }

    // Aurora curtains
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float x = p.x + sin(t * 0.3 + fi) * 0.2;
        float wave = sin(x * (3.0 + fi) + t * (0.4 + fi * 0.15) + fi * 1.7);
        float band = exp(-pow((p.y - (0.1 + fi * 0.15 + wave * 0.1)), 2.0) * 8.0);
        vec3 auroraCol = mix(vec3(0.1, 0.9, 0.4), vec3(0.3, 0.4, 1.0), fi / 4.0);
        auroraCol *= 0.6 + bass * 0.4 * intensity;
        color += auroraCol * band * (0.5 + 0.5 * sin(t + fi));
    }

    color *= 1.0 - smoothstep(0.9, 1.6, length(p));

    return vec4(color, 1.0);
}