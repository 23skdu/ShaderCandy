#include "base/common.glsl"

// turing_patterns - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float u = 0.5 + 0.5 * sin(p.x * 12.0 + t * 0.3) * cos(p.y * 10.0 - t * 0.2);
float v = 0.5 + 0.5 * cos(p.x * 8.0 - t * 0.4) * sin(p.y * 14.0 + t * 0.35);
float pat = smoothstep(0.4, 0.6, u - v);
vec3 color = mix(vec3(0.05, 0.1, 0.2), vec3(0.9, 0.7, 0.3), pat);
color *= 1.0 + bass * 0.2 * intensity;
return vec4(color, 1.0);

}
