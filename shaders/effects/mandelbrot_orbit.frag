#include "base/common.glsl"

// mandelbrot_orbit - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered * 1.5;
vec2 c = p + vec2(sin(t * 0.2) * 0.2, cos(t * 0.17) * 0.2);
vec2 z = vec2(0.0);
float n = 0.0;
for (int i = 0; i < 64; i++) {
    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    if (dot(z, z) > 4.0) { n = float(i); break; }
}
float v = n / 64.0;
vec3 color = 0.5 + 0.5 * cos(6.2831 * (v * 3.0 + vec3(0.0, 0.33, 0.67)));
color *= smoothstep(0.0, 0.1, v);
color *= 1.0 + bass * 0.2 * intensity;
return vec4(color, 1.0);

}
