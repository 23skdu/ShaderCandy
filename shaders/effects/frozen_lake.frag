#include "base/common.glsl"

// frozen_lake - Ice surface with cracks, snow drifts, and aurora reflection

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = mix(vec3(0.7, 0.8, 0.95), vec3(0.9, 0.95, 1.0), uv.y);

    // Ice cracks
    float crack = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float c = sin(p.x * (5.0 + fi * 3.0) + p.y * (3.0 + fi * 2.0) + fi * 2.0);
        crack = max(crack, smoothstep(0.92, 0.98, abs(c)));
    }
    color = mix(color, vec3(0.4, 0.55, 0.75), crack * 0.6);

    // Snow drifts
    float snow = smoothstep(0.1, 0.0, p.y + 0.4 + sin(p.x * 4.0) * 0.05);
    color = mix(color, vec3(1.0), snow * 0.7);

    // Aurora reflection on ice
    float aurora = 0.5 + 0.5 * sin(p.x * 3.0 + t * 0.4);
    float refl = smoothstep(0.0, -0.6, p.y) * aurora * 0.3;
    color += vec3(0.2, 0.6, 0.4) * refl * (0.5 + treble * 0.5 * intensity);

    // Sparkles
    float spark = smoothstep(0.02, 0.0, length(p - vec2(sin(t * 0.2) * 0.4, -0.1)));
    color += vec3(1.0) * spark * 0.5;

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return vec4(color, 1.0);
}