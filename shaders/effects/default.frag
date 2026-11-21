#include "base/common.glsl"

// Default Plasma Fractal - Classic demo scene effect with moving color bands

float defaultHashNoise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float defaultSmoothNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = defaultHashNoise(i);
    float b = defaultHashNoise(i + vec2(1.0, 0.0));
    float c = defaultHashNoise(i + vec2(0.0, 1.0));
    float d = defaultHashNoise(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float defaultFbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;

    for (int i = 0; i < 6; i++) {
        f += w * defaultSmoothNoise(p);
        p *= 2.0;
        w *= 0.5;
    }

    return f;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 p = uv * 6.0;

    float t = mod(time * speed * 0.3, 3600.0);

    // Multiple plasma layers
    float v1 = sin(p.x + t);
    float v2 = sin(p.y + t * 0.5);
    float v3 = sin(p.x + p.y + t * 0.7);
    float v4 = sin(sqrt(p.x * p.x + p.y * p.y) + t);

    float v5 = defaultFbm(p + vec2(t * 0.2, t * 0.1));
    float v6 = defaultFbm(p * 2.0 - vec2(t * 0.3, t * 0.15));

    // Combine
    float plasma = v1 + v2 + v3 + v4 + v5 * 2.0 + v6;
    plasma = (plasma + 5.0) / 10.0;

    // Color mapping
    float r = sin(plasma * 3.14159 + 0.0);
    float g = sin(plasma * 3.14159 + 2.094);
    float b = sin(plasma * 3.14159 + 4.188);

    vec3 col = vec3(r, g, b);
    col = col * 0.5 + 0.5;

    // Add glow
    col *= 1.0 + 0.3 * sin(plasma * 10.0);

    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.8;
    col *= vig;

    return vec4(col * intensity, alpha);
}
