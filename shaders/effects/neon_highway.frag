#include "base/common.glsl"

// neon_highway - Synthwave infinite highway at sunset with neon grid and light trails

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = mod(time * speed, 3600.0);

    vec2 p = centered;
    vec3 color = vec3(0.05, 0.0, 0.15);

    // Sunset sky
    float skyGrad = smoothstep(-0.2, 0.6, p.y);
    color = mix(vec3(0.2, 0.0, 0.3), vec3(1.0, 0.4, 0.1), skyGrad);

    // Sun
    vec2 sunPos = vec2(0.0, 0.35);
    float sunDist = length(p - sunPos);
    float sun = smoothstep(0.22, 0.18, sunDist);
    // Horizontal scanlines on sun
    float scan = step(0.5, fract(p.y * 12.0 + t * 0.5));
    color = mix(color, vec3(1.0, 0.9, 0.3), sun * (0.7 + 0.3 * scan));

    // Horizon line
    float horizon = 0.0;
    if (p.y < horizon) {
        // Perspective grid floor
        float depth = 1.0 / max(0.01, -(p.y + 0.05));
        float gx = p.x * depth;
        float gz = depth + t * (2.0 + bass * 3.0) * intensity;

        float gridX = smoothstep(0.02, 0.0, abs(fract(gx) - 0.5) - 0.48);
        float gridZ = smoothstep(0.02, 0.0, abs(fract(gz) - 0.5) - 0.48);
        float grid = max(gridX, gridZ);

        vec3 floorCol = mix(vec3(0.1, 0.0, 0.2), vec3(0.9, 0.1, 0.6), grid);
        // Fog
        float fog = exp(-depth * 0.15);
        floorCol *= fog;
        color = mix(color, floorCol, smoothstep(0.0, -0.05, p.y));

        // Light trails
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float laneX = (fi - 1.5) * 0.25;
            float trailZ = fract(gz * 0.1 + fi * 0.25);
            float trail = smoothstep(0.05, 0.0, abs(p.x - laneX) - 0.01) *
                          smoothstep(0.0, 0.3, trailZ) * smoothstep(0.8, 0.3, trailZ);
            color += vec3(1.0, 0.2, 0.8) * trail * fog * 0.8;
        }
    }

    // Vignette
    color *= 1.0 - smoothstep(0.8, 1.6, length(p));

    return vec4(color, 1.0);
}