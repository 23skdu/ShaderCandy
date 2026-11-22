#include "base/common.glsl"

// julia_orbit_traps - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered * 1.4;
vec2 c = vec2(-0.7 + 0.1 * sin(t), 0.27 + 0.1 * cos(t));
vec2 z = p;
float trap = 1e9;
for (int i = 0; i < 48; i++) {
    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    trap = min(trap, length(z));
    if (dot(z, z) > 100.0) break;
}
float v = clamp(trap * 0.5, 0.0, 1.0);
vec3 color = mix(vec3(0.9, 0.2, 0.4), vec3(0.1, 0.4, 0.9), v);
color *= 0.7 + 0.3 * sin(trap * 10.0 + t);
return vec4(color, 1.0);

}
