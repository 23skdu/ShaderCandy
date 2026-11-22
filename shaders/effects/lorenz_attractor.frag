#include "base/common.glsl"

// lorenz_attractor - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.0, 0.0, 0.05);
float x = 0.1, y = 0.0, z = 0.0;
for (int i = 0; i < 200; i++) {
    float dx = 10.0 * (y - x);
    float dy = x * (28.0 - z) - y;
    float dz = x * y - (8.0 / 3.0) * z;
    x += dx * 0.005; y += dy * 0.005; z += dz * 0.005;
    vec2 proj = vec2(x, z) * 0.025;
    float d = length(p - proj);
    color += vec3(0.2, 0.8, 1.0) * exp(-d * 40.0) * 0.02;
}
color *= 1.0 + bass * 0.2 * intensity;
return vec4(color, 1.0);

}
