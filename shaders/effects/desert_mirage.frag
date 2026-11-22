#include "base/common.glsl"

// desert_mirage - Heat haze over dunes with a shimmering mirage horizon

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    // Sky
    vec3 color = mix(vec3(0.5, 0.7, 1.0), vec3(0.9, 0.6, 0.3), smoothstep(-0.1, 0.4, p.y));

    // Sun
    float sun = smoothstep(0.12, 0.08, length(p - vec2(0.6, 0.5)));
    color += vec3(1.0, 0.9, 0.6) * sun;

    // Dunes
    float dune = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float h = -0.2 - fi * 0.15 + sin(p.x * (2.0 + fi) + t * 0.1) * 0.05;
        dune = max(dune, smoothstep(h + 0.02, h, p.y));
    }
    vec3 sandCol = mix(vec3(0.85, 0.65, 0.35), vec3(0.7, 0.5, 0.25), uv.y * 0.5 + 0.5);
    color = mix(color, sandCol, dune);

    // Heat haze mirage
    if (p.y < 0.1) {
        float haze = sin(p.x * 20.0 + t * 2.0) * 0.02 * (0.3 - p.y);
        vec2 refractUV = uv + vec2(haze, 0.0);
        float mirage = smoothstep(0.0, 0.3, -p.y) * 0.4;
        color = mix(color, vec3(0.6, 0.7, 0.9), mirage * (0.5 + 0.5 * sin(t + p.x * 5.0)));
    }

    // Heat shimmer lines
    float shimmer = sin(p.x * 30.0 + t * 3.0) * 0.5 + 0.5;
    color += vec3(0.9, 0.8, 0.6) * shimmer * smoothstep(0.1, -0.3, p.y) * 0.05;

    color *= 1.0 + bass * 0.1 * intensity;

    return vec4(color, 1.0);
}