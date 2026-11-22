#include "base/common.glsl"

// polar_night - Starry polar sky with a low moon and snow horizon

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = mix(vec3(0.0, 0.02, 0.08), vec3(0.05, 0.05, 0.15), uv.y);

    // Stars
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec2 sUV = p * (30.0 + fi * 25.0);
        float n = hash(floor(sUV) + fi * 13.0);
        if (n > 0.98) {
            float tw = 0.5 + 0.5 * sin(t * (0.8 + fi * 0.3) + n * 15.0);
            color += vec3(0.9, 0.95, 1.0) * tw * 0.7;
        }
    }

    // Moon
    vec2 moonPos = vec2(-0.5, 0.5);
    float moonDist = length(p - moonPos);
    float moon = smoothstep(0.12, 0.10, moonDist);
    color += vec3(0.9, 0.9, 0.8) * moon;
    // Moon glow
    color += vec3(0.4, 0.45, 0.6) * exp(-moonDist * 3.0) * 0.3;

    // Snow horizon
    float horizon = -0.6 + sin(p.x * 3.0) * 0.05;
    float snow = smoothstep(horizon + 0.05, horizon, p.y);
    color = mix(color, vec3(0.85, 0.9, 0.95), snow * 0.8);

    // Subtle aurora
    float aurora = 0.5 + 0.5 * sin(p.x * 2.0 + t * 0.2);
    color += vec3(0.1, 0.4, 0.3) * aurora * smoothstep(0.6, 0.2, p.y) * 0.2 * (0.5 + volume * 0.5 * intensity);

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return vec4(color, 1.0);
}