#include "base/common.glsl"

// lava_cavern - Molten lava flows in a dark cavern with glowing cracks

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = vec3(0.02, 0.01, 0.02);

    // Cavern walls
    float wall = smoothstep(0.0, 0.3, abs(p.x) - 0.6) + smoothstep(0.0, 0.2, p.y - 0.7);
    color = mix(color, vec3(0.08, 0.05, 0.04), wall);

    // Lava floor
    float lavaY = -0.5 + sin(p.x * 2.0 + t * 0.3) * 0.05;
    float lava = smoothstep(0.05, 0.0, p.y - lavaY);
    vec3 lavaCol = mix(vec3(0.9, 0.2, 0.0), vec3(1.0, 0.7, 0.1), 0.5 + 0.5 * sin(p.x * 4.0 + t));
    lavaCol *= 1.0 + bass * 0.5 * intensity;
    color = mix(color, lavaCol, lava);

    // Cracks in walls with lava glow
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float cx = sin(fi * 2.3) * 0.5;
        float cy = 0.2 + fi * 0.2;
        float d = length(p - vec2(cx, cy));
        float crack = smoothstep(0.15, 0.05, d) * (0.5 + 0.5 * sin(t * 1.5 + fi));
        color += vec3(1.0, 0.4, 0.0) * crack * 0.6;
    }

    // Embers
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        vec2 em = vec2(sin(fi * 3.1 + t * 0.2) * 0.7, mod(t * (0.1 + fi * 0.02) + fi * 0.5, 1.2) - 0.6);
        float e = smoothstep(0.015, 0.0, length(p - em));
        color += vec3(1.0, 0.5, 0.1) * e * 0.7;
    }

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return vec4(color, 1.0);
}