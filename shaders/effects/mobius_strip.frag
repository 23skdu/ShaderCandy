#include "base/common.glsl"

// mobius_strip - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float u = p.x * 3.0 + t * 0.4;
float v = p.y * 3.0;
float x = (1.0 + v * 0.3 * cos(u * 0.5)) * cos(u);
float y = (1.0 + v * 0.3 * cos(u * 0.5)) * sin(u);
float z = v * 0.3 * sin(u * 0.5);
vec2 proj = vec2(x, y + z * 0.4) * 0.35;
float d = length(p - proj);
float band = smoothstep(0.15, 0.0, d);
vec3 color = mix(vec3(0.05, 0.0, 0.15), vec3(0.9, 0.4, 0.8), band);
color += vec3(0.3, 0.8, 1.0) * exp(-d * 20.0) * 0.4;
return vec4(color, 1.0);

}
