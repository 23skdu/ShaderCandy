#include "base/common.glsl"

// klein_bottle - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float u = p.x * 3.0 + t * 0.3;
float v = p.y * 3.0;
float x = (2.0 + cos(v * 0.5)) * cos(u);
float y = (2.0 + cos(v * 0.5)) * sin(u);
float z = sin(v * 0.5);
vec2 proj = vec2(x, y + z * 0.5) * 0.25;
float d = length(p - proj);
vec3 color = vec3(0.1, 0.2, 0.4) + vec3(0.8, 0.5, 0.2) * exp(-d * 8.0);
color *= 1.0 + volume * 0.2 * intensity;
return vec4(color, 1.0);

}
