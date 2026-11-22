#include "base/common.glsl"

// quantum_rainbow - Prismatic light bands with quantum interference patterns

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = vec3(0.02, 0.0, 0.05);

    // Interference bands
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float phase = p.x * (4.0 + fi) + p.y * (3.0 - fi) + t * (0.5 + fi * 0.2);
        float band = 0.5 + 0.5 * sin(phase);
        band = pow(band, 2.0);
        vec3 hue = vec3(
            0.5 + 0.5 * sin(fi * 1.0 + t * 0.3),
            0.5 + 0.5 * sin(fi * 2.0 + t * 0.4 + 2.0),
            0.5 + 0.5 * sin(fi * 3.0 + t * 0.5 + 4.0)
        );
        color += hue * band * 0.15 * (0.6 + bass * 0.4 * intensity);
    }

    // Central prism
    float r = length(p);
    float prism = smoothstep(0.3, 0.0, r) * (0.5 + 0.5 * sin(t * 2.0));
    color += vec3(0.9, 0.9, 1.0) * prism * 0.4;

    // Vignette
    color *= 1.0 - smoothstep(0.8, 1.6, r);

    return vec4(color, 1.0);
}