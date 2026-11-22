#include "base/common.glsl"

// star_nursery - Colorful nebula with forming stars and dust lanes

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = vec3(0.02, 0.0, 0.05);

    // Nebula clouds
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float n = hash(floor(p * (6.0 + fi * 2.0)) + fi);
        float cloud = smoothstep(0.3, 0.7, n) * (0.4 + 0.3 * sin(t * 0.2 + fi));
        vec3 nebCol = mix(vec3(0.8, 0.2, 0.4), vec3(0.2, 0.4, 0.9), fi / 3.0);
        color += nebCol * cloud * 0.3;
    }

    // Forming stars (bright cores)
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        vec2 sp = vec2(hash(fi * 1.3) * 2.0 - 1.0, hash(fi * 7.9) * 2.0 - 1.0) * 0.8;
        float d = length(p - sp);
        float star = exp(-d * 8.0) * (0.6 + 0.4 * sin(t * 1.5 + fi));
        color += vec3(1.0, 0.95, 0.8) * star * 0.6;
        // Accretion disk
        float disk = smoothstep(0.12, 0.08, d) * 0.3;
        color += vec3(0.9, 0.5, 0.2) * disk * (0.5 + volume * 0.5 * intensity);
    }

    // Dust lanes
    float dust = smoothstep(0.1, 0.0, abs(sin(p.x * 3.0 + p.y * 2.0 + t * 0.1)));
    color *= 1.0 - dust * 0.3;

    color *= 1.0 - smoothstep(0.9, 1.7, length(p));

    return vec4(color, 1.0);
}