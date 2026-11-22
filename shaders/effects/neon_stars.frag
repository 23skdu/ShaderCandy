#include "base/common.glsl"

// neon_stars - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.02, 0.0, 0.08);
for (int i = 0; i < 15; i++) {
    float fi = float(i);
    vec2 sp = vec2(hash(fi * 3.1) * 2.0 - 1.0, hash(fi * 7.7) * 2.0 - 1.0) * 0.85;
    float d = length(p - sp);
    float core = exp(-d * 12.0);
    float rays = pow(max(0.0, 1.0 - abs(sin(atan2(p.y - sp.y, p.x - sp.x) * 4.0 + t))), 8.0) * 0.3;
    vec3 neon = mix(vec3(1.0, 0.2, 0.8), vec3(0.2, 0.8, 1.0), fi / 15.0);
    color += neon * (core + rays) * (0.6 + treble * 0.5 * intensity);
}
color *= 1.0 - smoothstep(0.9, 1.7, length(p));
return vec4(color, 1.0);

}
