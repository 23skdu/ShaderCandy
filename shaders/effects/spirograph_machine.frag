#include "base/common.glsl"

// spirograph_machine - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float R = 0.6, r = 0.25, d = 0.4;
float u = t * 0.5;
float x = (R - r) * cos(u) + d * cos((R - r) / r * u);
float y = (R - r) * sin(u) - d * sin((R - r) / r * u);
vec2 pt = vec2(x, y);
float trail = 0.0;
for (int i = 0; i < 200; i++) {
    float fi = float(i);
    float uu = fi * 0.05 + t * 0.5;
    float xx = (R - r) * cos(uu) + d * cos((R - r) / r * uu);
    float yy = (R - r) * sin(uu) - d * sin((R - r) / r * uu);
    float dd = length(p - vec2(xx, yy));
    trail += exp(-dd * 30.0) * 0.02;
}
vec3 color = vec3(0.02, 0.0, 0.08) + vec3(0.3, 0.8, 1.0) * trail;
color += vec3(1.0, 0.4, 0.7) * exp(-length(p - pt) * 20.0) * 0.5;
color *= 1.0 + volume * 0.2 * intensity;
return vec4(color, 1.0);

}
