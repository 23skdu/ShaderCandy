#include "base/common.glsl"

// voronoi_shatter - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float minD = 1e9;
vec2 minP = vec2(0.0);
for (int i = 0; i < 12; i++) {
    float fi = float(i);
    vec2 cell = vec2(hash(fi * 1.3) * 2.0 - 1.0, hash(fi * 7.9) * 2.0 - 1.0) * 0.8;
    cell += vec2(sin(t * 0.3 + fi), cos(t * 0.25 + fi)) * 0.1;
    float d = length(p - cell);
    if (d < minD) { minD = d; minP = cell; }
}
float edge = smoothstep(0.0, 0.02, minD - 0.05);
vec3 color = mix(vec3(0.8, 0.3, 0.1), vec3(0.1, 0.2, 0.5), hash(minP.x + minP.y * 10.0));
color *= edge;
color += vec3(1.0, 0.9, 0.7) * (1.0 - smoothstep(0.0, 0.03, minD)) * 0.6;
color *= 1.0 + bass * 0.2 * intensity;
return vec4(color, 1.0);

}
