#include "base/common.glsl"

// tesseract_projection - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
vec3 color = vec3(0.0, 0.0, 0.05);
for (int i = 0; i < 16; i++) {
    float fi = float(i);
    float a = fi * 0.3927 + t * 0.2;
    float r = 0.6;
    vec2 v = vec2(cos(a), sin(a)) * r;
    v += vec2(sin(t * 0.5 + fi) * 0.1, cos(t * 0.4 + fi) * 0.1);
    float d = length(p - v);
    color += vec3(0.6, 0.8, 1.0) * exp(-d * 30.0) * 0.15;
}
// connecting lines approximation
float grid = smoothstep(0.01, 0.0, abs(sin(p.x * 8.0 + t)) * abs(sin(p.y * 8.0 - t)));
color += vec3(0.3, 0.5, 0.9) * grid * 0.2;
color *= 1.0 + bass * 0.2 * intensity;
return vec4(color, 1.0);

}
