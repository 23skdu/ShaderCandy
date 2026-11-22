#include "base/common.glsl"

// lissajous_3d - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.0, 0.0, 0.05);
for (int i = 0; i < 120; i++) {
    float fi = float(i);
    float u = fi * 0.08 + t * 0.4;
    float x = sin(3.0 * u + 1.0) * 0.5;
    float y = sin(4.0 * u) * 0.5;
    float z = sin(5.0 * u + 2.0) * 0.3;
    vec2 proj = vec2(x, y + z * 0.4);
    float d = length(p - proj);
    color += vec3(0.9, 0.6, 0.2) * exp(-d * 40.0) * 0.05;
}
color *= 1.0 - smoothstep(0.9, 1.6, length(p));
return vec4(color, 1.0);

}
