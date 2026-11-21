#include "base/common.glsl"

// Volumetric Clouds - Raymarched 3D FBM cloudscape with sky gradient and sun glow

vec4 effect_main(vec2 centered, vec2 uv) {
    float t_anim = time * speed;

    // Simple raymarching through a noise field
    vec3 ro = vec3(0.0, 0.0, t_anim * 0.2); // Ray origin
    vec3 rd = normalize(vec3(centered, 1.2)); // Ray direction

    float density = 0.0;
    vec3 cloudCol = vec3(0.0);

    float t = 0.0;
    for (int i = 0; i < 48; i++) {
        vec3 p = ro + rd * t;

        // Multi-layered noise for clouds
        float f = fbm(p * 0.8 + vec3(t_anim * 0.05), 3);
        f = smoothstep(0.2, 0.6, f);

        if (f > 0.01) {
            float ld = f * 0.1; // Local density
            density += ld * (1.0 - density);

            // Subtle lighting based on density gradient
            vec3 light = vec3(0.6, 0.7, 1.0) * (1.0 - f * 0.5);
            cloudCol += light * ld * (1.0 - density);
        }

        t += 0.15;
        if (density > 0.99) break;
    }

    // Aesthetic sky gradient
    vec3 skyCol = mix(vec3(0.05, 0.1, 0.25), vec3(0.15, 0.3, 0.6), rd.y * 0.5 + 0.5);

    // Mix sky and clouds
    vec3 finalCol = mix(skyCol, cloudCol, density);

    // Add sun glow
    vec3 sunPos = normalize(vec3(0.5, 0.5, 1.0));
    float sun = pow(max(dot(rd, sunPos), 0.0), 32.0);
    finalCol += vec3(1.0, 0.9, 0.7) * sun;

    return vec4(finalCol * intensity, alpha);
}
