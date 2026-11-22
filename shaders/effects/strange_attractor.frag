#include "base/common.glsl"

// strange_attractor - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.02, 0.0, 0.08);
float a = 1.4, b = 0.3;
float x = 0.1, y = 0.1;
for (int i = 0; i < 300; i++) {
    float cc = 0.5 + 0.5 * sin(t * 0.1);
    float dd = 1.6 + 0.2 * cos(t * 0.07);
    float nx = sin(a * y) + cc * cos(a * x);
    float ny = sin(b * x) + dd * cos(b * y);
    x = nx; y = ny;
    vec2 proj = vec2(x, y) * 0.35;
    float d2 = length(p - proj);
    color += vec3(1.0, 0.4, 0.7) * exp(-d2 * 30.0) * 0.015;
}
return vec4(color, 1.0);

}
