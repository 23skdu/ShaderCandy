#include "base/common.glsl"

// newton_fractal - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered * 1.5;
vec2 z = p;
int root = 0;
for (int i = 0; i < 32; i++) {
    // z^3 - 1
    vec2 z2 = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
    vec2 z3 = vec2(z2.x * z.x - z2.y * z.y, z2.x * z.y + z2.y * z.x);
    vec2 f = z3 - vec2(1.0, 0.0);
    vec2 df = 3.0 * z2;
    z = z - vec2((f.x * df.x + f.y * df.y) / (df.x * df.x + df.y * df.y),
                  (f.y * df.x - f.x * df.y) / (df.x * df.x + df.y * df.y));
    if (length(f) < 1e-4) break;
}
if (distance(z, vec2(1.0, 0.0)) < 0.5) root = 0;
else if (distance(z, vec2(-0.5, 0.866)) < 0.5) root = 1;
else root = 2;
vec3 cols[3];
cols[0] = vec3(1.0, 0.3, 0.3);
cols[1] = vec3(0.3, 1.0, 0.4);
cols[2] = vec3(0.3, 0.4, 1.0);
vec3 color = cols[root] * (0.6 + 0.4 * sin(t + float(root)));
color *= 1.0 - smoothstep(0.0, 0.02, length(z - p));
return vec4(color, 1.0);

}
