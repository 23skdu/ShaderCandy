#include "base/common.glsl"

// unicorn - Magical scene with unicorn and sparkles

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Magical background
    vec3 color = vec3(0.1, 0.05, 0.15);
    color += hsv2rgb(vec3(fract(t * 0.05 + length(p) * 0.1), 0.5, 0.2));
    
    // Magical particles
    for (float i = 0.0; i < 20.0; i++) {
        float fi = i;
        vec2 particlePos = vec2(
            sin(t * 0.5 + fi * 2.0) * 1.5,
            cos(t * 0.3 + fi * 1.5) * 1.2 + fi * 0.08
        );
        float dist = length(p - particlePos);
        float particle = exp(-dist * 3.0) * (0.5 + 0.5 * sin(t * 4.0 + fi * 3.0));
        vec3 particleColor = hsv2rgb(vec3(0.8 + fi * 0.02, 0.8, 1.0));
        color += particleColor * particle * 0.15;
    }
    
    // Unicorn silhouette (simplified side view)
    vec2 uniPos = vec2(0.0, -0.3);
    vec2 uniP = p - uniPos;
    
    // Body
    float body = length(uniP * vec2(0.8, 1.2)) - 0.4;
    body = smoothstep(0.02, 0.0, -body);
    
    // Neck and head
    vec2 neckP = uniP - vec2(0.1, 0.5);
    float neck = length(neckP * vec2(0.6, 1.5)) - 0.25;
    neck = smoothstep(0.02, 0.0, -neck);
    
    // Snout
    vec2 snoutP = uniP - vec2(0.3, 0.65);
    float snout = length(snoutP * vec2(1.5, 1.0)) - 0.12;
    snout = smoothstep(0.02, 0.0, -snout);
    
    // Horn (spiral)
    vec2 hornP = uniP - vec2(0.05, 0.85);
    float horn = length(hornP - vec2(0.0, hornP.y * 0.5)) - 0.02 - hornP.y * 0.03;
    horn = smoothstep(0.02, 0.0, -horn);
    // Spiral pattern
    float spiral = sin(hornP.y * 20.0 + t * 3.0) * 0.5 + 0.5;
    
    // Mane (rainbow flowing)
    vec2 maneP = uniP - vec2(-0.1, 0.6);
    float mane = length(maneP * vec2(0.5, 1.0)) - 0.15;
    mane = smoothstep(0.02, 0.0, -mane);
    vec3 maneColor = hsv2rgb(vec3(fract(uniP.y * 0.5 + t * 0.2), 0.7, 0.9));
    
    // Tail (flowing rainbow)
    vec2 tailP = uniP - vec2(-0.2, -0.6);
    float tail = length(tailP * vec2(0.4, 1.5)) - 0.15;
    tail = smoothstep(0.02, 0.0, -tail);
    
    // Legs
    vec2 legP = uniP - vec2(0.15, -0.9);
    float leg = length(legP * vec2(0.5, 2.0)) - 0.15;
    leg = smoothstep(0.02, 0.0, -leg);
    
    // Combine unicorn
    float unicorn = max(body, neck);
    unicorn = max(unicorn, snout);
    unicorn = max(unicorn, horn);
    unicorn = max(unicorn, mane);
    unicorn = max(unicorn, tail);
    unicorn = max(unicorn, leg);
    
    // Unicorn color (white with rainbow mane/tail)
    vec3 uniColor = vec3(0.95, 0.95, 1.0);
    uniColor = mix(uniColor, maneColor, mane * 0.8);
    uniColor = mix(uniColor, hsv2rgb(vec3(fract(t * 0.15), 0.7, 0.9)), tail * 0.6);
    
    // Horn glow
    vec3 hornGlow = vec3(1.0, 0.8, 1.0) * (0.5 + 0.5 * sin(t * 5.0));
    uniColor = mix(uniColor, hornGlow, horn);
    
    color = mix(color, uniColor, unicorn);
    
    // Horn spiral shine
    color += vec3(1.0, 0.9, 1.0) * horn * spiral * 0.3;
    
    // Eyes
    vec2 eyeP = uniP - vec2(0.2, 0.6);
    float eye = smoothstep(0.03, 0.02, length(eyeP));
    color = mix(color, vec3(0.8, 0.6, 0.9), eye);
    float pupil = smoothstep(0.015, 0.01, length(eyeP));
    color = mix(color, vec3(0.1, 0.05, 0.15), pupil);
    
    // Sparkles
    for (float i = 0.0; i < 30.0; i++) {
        float fi = i;
        vec2 sparkPos = p + vec2(
            sin(t * 0.4 + fi * 2.0) * 0.8,
            cos(t * 0.5 + fi * 1.5) * 0.6
        );
        float spark = smoothstep(0.015, 0.0, length(sparkPos));
        spark *= 0.5 + 0.5 * sin(t * 6.0 + fi * 4.0);
        color += hsv2rgb(vec3(0.75 + fi * 0.01, 0.6, 1.0)) * spark * 0.5;
    }
    
    // Rainbow light effect
    float rainbowAngle = atan2(p.y, p.x) + t;
    vec3 rainbowLight = hsv2rgb(vec3(fract(rainbowAngle * 0.1), 0.6, 0.4));
    color += rainbowLight * 0.15;
    
    color *= intensity;
    return vec4(color, alpha);
}