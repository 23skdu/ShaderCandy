#include "base/common.glsl"

// reaction_diffusion_pulse - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float a = 0.5 + 0.5 * sin(p.x * 8.0 + t) * cos(p.y * 6.0 - t * 0.7);
float b = 0.5 + 0.5 * cos(p.x * 5.0 - t * 0.5) * sin(p.y * 9.0 + t * 0.9);
float pat = a * b;
vec3 color = mix(vec3(0.1, 0.0, 0.2), vec3(0.9, 0.4, 0.1), pat);
color += vec3(0.2, 0.8, 1.0) * smoothstep(0.7, 0.9, pat) * 0.5 * (1.0 + mid * intensity);
color *= 1.0 - smoothstep(0.9, 1.5, length(p));
return vec4(color, 1.0);

}
