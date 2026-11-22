#include "base/common.glsl"

// fourier_epicycles - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.02, 0.02, 0.08);
vec2 pt = vec2(0.0);
float u = t * 0.5;
for (int k = 1; k <= 6; k++) {
    float fk = float(k);
    float amp = 1.0 / fk;
    float phase = fk * u;
    pt += vec2(cos(phase), sin(phase)) * amp * 0.4;
}
// draw trail
for (int i = 0; i < 150; i++) {
    float fi = float(i);
    float uu = fi * 0.04 + t * 0.5;
    vec2 ppt = vec2(0.0);
    for (int k = 1; k <= 6; k++) {
        float fk = float(k);
        ppt += vec2(cos(fk * uu), sin(fk * uu)) * (1.0 / fk) * 0.4;
    }
    float d = length(p - ppt);
    color += vec3(0.4, 0.9, 0.7) * exp(-d * 50.0) * 0.02;
}
color += vec3(1.0, 0.3, 0.6) * exp(-length(p - pt) * 20.0) * 0.6;
color *= 1.0 + bass * 0.2 * intensity;
return vec4(color, 1.0);

}
