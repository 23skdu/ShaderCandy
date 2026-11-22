#include "base/common.glsl"

// magnet_fractal - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered * 1.4;
vec2 z = p;
float n = 0.0;
for (int i = 0; i < 32; i++) {
    float r2 = dot(z, z);
    if (r2 > 100.0) { n = float(i); break; }
    float x = z.x, y = z.y;
    float denom = (3.0 * x * x + (y - 1.0) * (y - 1.0));
    denom = max(denom, 1e-6);
    vec2 nz = vec2((x * (x * x - 3.0 * y * (y - 2.0))) / denom,
                    (y * (3.0 * x * x - (y - 1.0) * (y - 1.0) + 1.0)) / denom);
    z = nz + p * 0.1;
}
float v = n / 32.0;
vec3 color = 0.5 + 0.5 * cos(6.2831 * (v + vec3(0.0, 0.33, 0.67)));
color *= smoothstep(0.0, 0.2, v);
return vec4(color, 1.0);

}
