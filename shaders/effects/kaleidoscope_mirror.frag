#include "base/common.glsl"

// kaleidoscope_mirror - generated shader

vec4 effect_main(vec2 centered, vec2 uv) {

float t = mod(time * speed, 3600.0);
vec2 p = centered;
float ang = atan2(p.y, p.x);
float r = length(p);
int segs = 8;
float seg = 6.28318 / float(segs);
ang = mod(ang, seg);
ang = abs(ang - seg * 0.5);
vec2 q = vec2(cos(ang), sin(ang)) * r;
float pat = 0.5 + 0.5 * sin(q.x * 10.0 + t) * cos(q.y * 8.0 - t * 0.7);
vec3 color = mix(vec3(0.1, 0.0, 0.2), vec3(0.9, 0.4, 1.0), pat);
color *= exp(-r * 0.8);
color *= 1.0 + treble * 0.3 * intensity;
return vec4(color, 1.0);

}
