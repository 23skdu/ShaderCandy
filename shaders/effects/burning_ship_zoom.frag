#include "base/common.glsl"

// burning_ship_zoom - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered * 1.2;
float zoom = 1.0 + 0.5 * sin(t * 0.2);
p /= zoom;
vec2 c = p + vec2(-0.5, -0.5);
vec2 z = vec2(0.0);
float n = 0.0;
for (int i = 0; i < 48; i++) {
    z = vec2(abs(z.x), abs(z.y));
    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    if (dot(z, z) > 4.0) { n = float(i); break; }
}
float v = n / 48.0;
vec3 color = 0.5 + 0.5 * cos(6.2831 * (v * 4.0 + vec3(0.0, 0.1, 0.2)));
color *= smoothstep(0.0, 0.15, v);
return vec4(color, 1.0);

}
