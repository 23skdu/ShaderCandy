#include "base/common.glsl"

// rainbow_lasers - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.0, 0.0, 0.05);
for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float y = sin(p.x * (2.5 + fi) + t * (1.0 + fi * 0.4)) * 0.12 * (1.0 + fi * 0.3);
    float beam = smoothstep(0.015, 0.0, abs(p.y - y));
    vec3 hue = vec3(0.5 + 0.5 * sin(fi + t), 0.5 + 0.5 * sin(fi * 2.0 + t * 1.3), 0.5 + 0.5 * sin(fi * 3.0 + t * 1.7));
    color += hue * beam * (0.7 + bass * 0.5 * intensity);
}
for (int i = 0; i < 20; i++) {
    float fi = float(i);
    vec2 sp = vec2(hash(fi * 1.7) * 2.0 - 1.0, hash(fi * 9.3) * 2.0 - 1.0) * 0.9;
    float star = smoothstep(0.012, 0.0, length(p - sp)) * (0.5 + 0.5 * sin(t * 2.0 + fi));
    color += vec3(0.8, 0.9, 1.0) * star * 0.5;
}
color *= 1.0 - smoothstep(0.9, 1.6, length(p));
return vec4(color, 1.0);

}
