#include "base/common.glsl"

// bioluminescent_bay - Glowing plankton trails in a calm night bay

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = mix(vec3(0.0, 0.02, 0.08), vec3(0.0, 0.05, 0.15), uv.y);

    // Moonlight shimmer on water
    float shimmer = 0.5 + 0.5 * sin(p.x * 12.0 + t * 0.5) * sin(p.y * 8.0 - t * 0.3);
    color += vec3(0.4, 0.5, 0.7) * shimmer * 0.15;

    // Bioluminescent trails following mouse
    vec2 m = mouse * 2.0 - 1.0;
    m.x *= resolution.x / resolution.y;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        vec2 trailPos = m + vec2(sin(t * 0.4 + fi) * 0.3, cos(t * 0.3 + fi) * 0.2);
        float d = length(p - trailPos);
        float glow = exp(-d * 4.0) * (0.6 + mid * 0.4);
        vec3 bioCol = mix(vec3(0.2, 1.0, 0.6), vec3(0.1, 0.8, 1.0), fi / 6.0);
        color += bioCol * glow * (0.7 + intensity * 0.3);
    }

    // Ambient plankton sparkles
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 sp = vec2(hash(fi * 3.7), hash(fi * 9.1)) * 2.0 - 1.0;
        sp.x *= 1.2;
        float tw = 0.5 + 0.5 * sin(t * (1.5 + fi) + fi * 5.0);
        float spark = smoothstep(0.03, 0.0, length(p - sp)) * tw;
        color += vec3(0.3, 1.0, 0.7) * spark * 0.4;
    }

    color *= 1.0 - smoothstep(0.8, 1.6, length(p));

    return vec4(color, 1.0);
}