#include "base/common.glsl"

// hiphop - Urban aesthetic with street vibes and graffiti

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Brick wall background
    vec3 color = vec3(0.1, 0.08, 0.06);
    
    // Brick pattern
    vec2 brickId = floor(p * vec2(6.0, 3.0));
    vec2 brickP = fract(p * vec2(6.0, 3.0));
    
    float brickLine = step(0.05, brickP.x) * step(0.1, brickP.y);
    float brick = brickLine;
    
    // Brick color variation
    float brickVar = fract(sin(dot(brickId, vec2(127.1, 311.7))) * 43758.5453);
    vec3 brickColor = mix(vec3(0.15, 0.1, 0.08), vec3(0.2, 0.12, 0.1), brickVar);
    color = mix(color, brickColor, brick * 0.8);
    
    // Graffiti spray paint effect
    float spray = 0.0;
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        vec2 sprayPos = vec2(
            sin(fi * 2.3) * 0.5 + cos(t * 0.3 + fi) * 0.3,
            sin(fi * 1.7) * 0.3 + cos(t * 0.2 + fi * 0.5) * 0.2
        );
        float sprayDist = length(p - sprayPos);
        float sprayNoise = noise(p * 20.0 + fi * 10.0);
        spray += smoothstep(0.4, 0.0, sprayDist) * sprayNoise;
    }
    
    vec3 graffitiColor = hsv2rgb(vec3(0.9 + t * 0.1, 0.9, 1.0));
    color += graffitiColor * spray * 0.6;
    
    // Drip effect
    float drip = fract(p.y * 10.0 + t * 0.2);
    drip = smoothstep(0.0, 0.1, drip) * smoothstep(0.2, 0.1, drip);
    float dripX = abs(p.x - round(p.x * 8.0) / 8.0);
    drip *= smoothstep(0.02, 0.0, dripX);
    color += vec3(0.9, 0.2, 0.5) * drip * 0.3;
    
    // Street light flicker
    float flicker = 0.8 + 0.2 * sin(t * 15.0);
    color *= flicker;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}