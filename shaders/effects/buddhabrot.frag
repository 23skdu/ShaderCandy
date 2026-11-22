#include "base/common.glsl"

// buddhabrot - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered * 1.3;
vec3 color = vec3(0.0);
for (int s = 0; s < 8; s++) {
    float fs = float(s);
    vec2 c = vec2(hash(fs * 1.3 + t * 0.01) * 4.0 - 2.0, hash(fs * 7.9) * 4.0 - 2.0);
    vec2 z = c;
    for (int i = 0; i < 60; i++) {
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (dot(z, z) > 4.0) break;
        vec2 proj = z * 0.3;
        float d = length(p - proj);
        color += vec3(0.4, 0.7, 1.0) * exp(-d * 25.0) * 0.02;
    }
}
color *= 1.0 + bass * 0.2 * intensity;
return vec4(color, 1.0);

}
