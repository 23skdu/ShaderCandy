#include "base/common.glsl"

// hyperbolic_tiling - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float r = length(p);
float ang = atan2(p.y, p.x);
float rings = sin(log(r + 0.1) * 6.0 + t) * 0.5 + 0.5;
float spokes = sin(ang * 7.0 + t * 0.5) * 0.5 + 0.5;
float pat = rings * spokes;
vec3 color = mix(vec3(0.05, 0.0, 0.15), vec3(0.9, 0.3, 0.6), pat);
color *= exp(-r * 1.2);
color *= 1.0 + mid * 0.3 * intensity;
return vec4(color, 1.0);

}
