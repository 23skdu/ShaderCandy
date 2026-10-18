#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec3 col = vec3(0.0);

    // Loop-invariant for the 100 star layers below.
    float rCentered = length(centered);
    
    // Starfield
    //
    // Almost every iteration of this 100-step loop is rejected by the
    // original step(d, size) test, so the sqrt that produced d was wasted.
    // d and size are both non-negative, so d < size is exactly
    // dot(st - pos, st - pos) < size * size, and the sqrt is deferred to the
    // few iterations that actually contribute. An int loop index also lets
    // i * 0.0123 / 123.4 / 456.7 fold to compile-time constants.
    for (int i = 0; i < 100; i++) {
        float fi = float(i);
        float z = fract(fi * 0.0123 - t * 0.5);
        float fade = 1.0 - z;

        vec2 st = centered * (0.5 / z);
        float a = atan(st.y, st.x) + z * 5.0;
        // length(centered) * 0.5 / z, with length(centered) hoisted
        float r = rCentered * 0.5 / z;

        vec2 pos = vec2(sin(fi * 123.4 + a), cos(fi * 456.7 + a)) * r;

        vec2 q = st - pos;
        float size = 0.005 / z;
        float d2 = dot(q, q);

        if (d2 < size * size) {
            float d = sqrt(d2);
            col += vec3(1.0, 0.8, 0.5) * fade * max(0.0, 1.0 - d / size);
        }
    }
    
    // Background nebula
    col += vec3(0.1, 0.0, 0.2) * (0.5 + 0.5 * sin(centered.y * 5.0 + t));
    
    col *= intensity;
    return vec4(col, alpha);
}
