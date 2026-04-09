#include "base/common.glsl"

// area_51 - Aliens and UFO sighting at a secret desert base

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Background: Desert Night with gradient
    vec3 color = mix(vec3(0.0, 0.0, 0.05), vec3(0.08, 0.03, 0.15), uv.y);
    
    // Animated stars with twinkling
    for(float i = 0.0; i < 3.0; i++) {
        float fi = i;
        vec2 starUV = p * (50.0 + fi * 20.0);
        float n = fract(sin(dot(floor(starUV) + vec2(fi * 456.7, fi * 123.4), vec2(12.9898, 78.233))) * 43758.5453);
        float twinkle = 0.5 + 0.5 * sin(t * (2.0 + fi) + n * 10.0);
        if (n > 0.98 - fi * 0.01) {
            color += pow(fract(sin(n + t) * 43758.5453), 10.0) * twinkle * (1.0 - fi * 0.2);
        }
    }
    
    // Moon
    vec2 moonPos = vec2(0.7, 0.7);
    float moonDist = length(p - moonPos);
    float moon = smoothstep(0.15, 0.14, moonDist);
    color += vec3(0.9, 0.9, 0.8) * moon;
    // Moon crater shadow
    float crater = smoothstep(0.03, 0.02, length(p - moonPos - vec2(0.03, 0.02)));
    color -= vec3(0.1) * crater * moon;
    
    // Desert Ground
    float ground = -0.6;
    
    if (p.y < ground) {
        // Sandy desert color
        color = mix(vec3(0.15, 0.1, 0.05), vec3(0.08, 0.05, 0.02), p.y + 0.6);
        
        // Distant fence posts
        float fencePattern = fract(p.x * 8.0);
        if (fencePattern < 0.02 && p.y > ground - 0.1) {
            color += vec3(0.05);
        }
        // Barbed wire
        if (abs(p.y - ground + 0.05) < 0.005 && fract(p.x * 40.0) < 0.5) {
            color += vec3(0.1);
        }
    }
    
    // UFO
    float ufoX = sin(t * 0.3) * 0.6;
    float ufoY = 0.6 + sin(t * 0.5) * 0.1;
    vec2 ufoPos = vec2(ufoX, ufoY);
    float ufoDist = length(p - ufoPos);
    
    // UFO body
    float ufoBody = length(p - ufoPos - vec2(0.0, 0.02)) - 0.12;
    if (ufoBody < 0.0 && p.y > ground) {
        color = mix(color, vec3(0.5, 0.5, 0.6), 0.8);
    }
    
    // UFO dome
    float dome = length(p - ufoPos - vec2(0.0, 0.08)) - 0.06;
    if (dome < 0.0 && p.y > ground) {
        color += vec3(0.3, 0.6, 1.0) * 0.5;
    }
    
    // UFO beam
    float beamDist = abs(p.x - ufoX);
    float beam = exp(-beamDist * 8.0) * smoothstep(-1.0, ground + 1.5, p.y);
    vec3 beamColor = vec3(0.2, 1.0, 0.3) * (0.7 + 0.3 * sin(t * 3.0));
    color += beamColor * beam * 0.3;
    
    // Warning lights
    if (p.y > 0.75 && p.y < 0.8) {
        float warningPulse = step(0.3, sin(t * 3.0 + p.x * 5.0));
        color += vec3(1.0, 0.0, 0.0) * warningPulse * 0.15;
    }
    
    // Searchlights from base
    float lightAngle = t * 0.5;
    vec2 lightDir = vec2(cos(lightAngle), sin(lightAngle * 0.3));
    vec2 lightPos = vec2(-0.6, ground);
    float lightDist = length(p - lightPos);
    float lightBeam = smoothstep(0.3, 0.0, abs(dot(normalize(p - lightPos), vec2(-lightDir.y, lightDir.x))));
    lightBeam *= exp(-lightDist * 2.0) * (0.5 + 0.5 * sin(t * 2.0));
    color += vec3(0.9, 0.9, 0.7) * lightBeam * 0.2;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.4;
    
    color *= intensity;
    return vec4(color, alpha);
}