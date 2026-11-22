#include "base/common.glsl"

// perlin_flow_field - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.0, 0.02, 0.08);
for (int i = 0; i < 60; i++) {
    float fi = float(i);
    vec2 pos = p;
    for (int j = 0; j < 8; j++) {
        float fj = float(j);
        pos += vec2(sin(pos.y * 3.0 + t * 0.2 + fj), cos(pos.x * 3.0 - t * 0.15 + fj)) * 0.05;
    }
    float d = length(pos - p);
    color += vec3(0.3, 0.6, 1.0) * exp(-d * 200.0) * 0.05;
}
color *= 1.0 - smoothstep(0.9, 1.6, length(p));
return vec4(color, 1.0);

}
