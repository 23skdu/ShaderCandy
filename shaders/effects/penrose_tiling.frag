#include "base/common.glsl"

// penrose_tiling - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered * 2.0;
float scale = 0.5;
vec3 color = vec3(0.05, 0.05, 0.1);
for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float a = fi * 1.2566 + t * 0.1;
    vec2 g = vec2(cos(a), sin(a)) * scale;
    float band = smoothstep(0.05, 0.0, abs(dot(p, vec2(-sin(a), cos(a))) - (scale * 0.5)));
    color += mix(vec3(0.9, 0.6, 0.2), vec3(0.2, 0.5, 0.9), fi / 5.0) * band * 0.25;
    scale *= 0.618;
}
color *= 1.0 - smoothstep(1.0, 2.0, length(p));
return vec4(color, 1.0);

}
