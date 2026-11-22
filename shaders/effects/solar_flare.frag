#include "base/common.glsl"

// solar_flare - Animated solar surface with convection cells, sunspots, and prominences

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    float r = length(p);

    // Base photosphere color
    vec3 color = vec3(0.0);

    // Solar disk
    float disk = smoothstep(0.02, 0.0, r - 0.85);

    if (disk > 0.0) {
        // Convection cells via domain-warped FBM
        vec2 q = p * 3.0;
        float n1 = hash(q + vec2(t * 0.05, 0.0));
        float n2 = hash(q * 2.0 + vec2(0.0, t * 0.03));
        float cells = 0.5 + 0.5 * sin((q.x + n1) * 4.0 + (q.y + n2) * 3.0);

        // Sunspots
        float spots = hash(floor(p * 8.0));
        spots = step(0.92, spots);

        vec3 hot = vec3(1.0, 0.9, 0.5);
        vec3 cool = vec3(0.8, 0.3, 0.05);
        vec3 surf = mix(cool, hot, cells);
        surf *= (1.0 - spots * 0.6);

        // Audio boost
        surf *= 1.0 + bass * 0.3 * intensity;

        color = surf * disk;
    }

    // Limb prominences
    if (r > 0.80 && r < 1.15) {
        float angle = atan(p.y, p.x);
        float prom = 0.5 + 0.5 * sin(angle * 6.0 + t * 0.8);
        float limb = smoothstep(0.0, 0.05, r - 0.85) * smoothstep(0.15, 0.0, r - 0.95);
        color += vec3(1.0, 0.4, 0.1) * prom * limb * (0.6 + bass * 0.4);
    }

    // Corona glow
    float corona = exp(-r * 2.5) * 0.4;
    color += vec3(1.0, 0.7, 0.3) * corona * (0.8 + volume * 0.4);

    return vec4(color, 1.0);
}