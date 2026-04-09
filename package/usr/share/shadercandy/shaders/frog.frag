#include "base/common.glsl"

// frog - Pond scene with frog on lily pad and sun in sky

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Sun orbit
    float sunAngle = t * 0.1;
    float sunX = cos(sunAngle) * 0.4;
    float sunY = sin(sunAngle) * 0.2 + 0.6;
    
    // Sky gradient based on sun position
    float sunHeight = sunY;
    vec3 skyColorTop = mix(vec3(0.0, 0.1, 0.3), vec3(0.9, 0.6, 0.3), smoothstep(-0.5, 0.5, sunHeight));
    vec3 skyColorBottom = mix(vec3(0.3, 0.5, 0.7), vec3(0.9, 0.4, 0.2), smoothstep(-0.5, 0.5, sunHeight));
    vec3 color = mix(skyColorBottom, skyColorTop, uv.y);
    
    // Sun
    vec2 sunPos = p - vec2(sunX, sunY);
    float sunDist = length(sunPos);
    float sun = smoothstep(0.1, 0.08, sunDist);
    vec3 sunColor = vec3(1.0, 0.9, 0.6);
    float sunGlow = exp(-sunDist * 4.0) * 0.4;
    color = mix(color, sunColor, sun);
    color += sunColor * sunGlow;
    
    // Water (bottom portion)
    if (p.y < -0.2) {
        vec3 waterColor = vec3(0.1, 0.4, 0.6);
        
        // Sun reflection on water
        float reflectDist = length(p - vec2(sunX, -0.2));
        float reflect = exp(-reflectDist * 3.0) * 0.5;
        color = mix(waterColor, sunColor, reflect);
        
        // Water ripples
        float ripple = sin(length(p) * 10.0 - t * 2.0) * 0.5 + 0.5;
        color += vec3(0.1, 0.15, 0.2) * ripple * 0.1;
    }
    
    // Lily pad (center)
    vec2 padP = p;
    float pad = length(padP) - 0.5;
    pad = max(pad, abs(p.y + 0.35) - 0.03);
    
    // Notch in lily pad
    float notch = length(padP - vec2(0.6, 0.0)) - 0.3;
    pad = max(pad, -notch);
    pad = smoothstep(0.02, 0.0, -pad);
    
    // Lily pad color (green with veins)
    vec3 padColor = vec3(0.1, 0.5, 0.1);
    float vein = sin(length(p) * 12.0 + atan(p.y, p.x) * 4.0);
    padColor *= 0.9 + 0.1 * vein;
    color = mix(color, padColor, pad);
    
    // Frog on lily pad
    vec2 frogP = p - vec2(0.0, -0.25);
    
    // Body
    float body = length(frogP * vec2(0.8, 1.2)) - 0.25;
    body = smoothstep(0.02, 0.0, -body);
    
    // Eyes (bulging)
    vec2 eyeLP = frogP - vec2(-0.15, 0.18);
    vec2 eyeRP = frogP - vec2(0.15, 0.18);
    float eyeL = length(eyeLP) - 0.1;
    float eyeR = length(eyeRP) - 0.1;
    float eyes = max(smoothstep(0.02, 0.0, -eyeL), smoothstep(0.02, 0.0, -eyeR));
    
    // Pupils
    vec2 pupilLP = eyeLP + vec2(0.02, 0.02);
    vec2 pupilRP = eyeRP + vec2(-0.02, 0.02);
    float pupilL = length(pupilLP) - 0.04;
    float pupilR = length(pupilRP) - 0.04;
    float pupils = max(smoothstep(0.01, 0.0, -pupilL), smoothstep(0.01, 0.0, -pupilR));
    
    // Frog color (bright green)
    vec3 frogColor = vec3(0.4, 0.8, 0.2);
    color = mix(color, frogColor, body);
    color = mix(color, vec3(0.3, 0.7, 0.15), eyes);
    
    // Pupils (black)
    color = mix(color, vec3(0.0), pupils);
    
    // Legs (folded)
    vec2 legLP = frogP - vec2(-0.25, -0.1);
    vec2 legRP = frogP - vec2(0.25, -0.1);
    float legL = length(legLP * vec2(1.5, 1.0)) - 0.12;
    float legR = length(legRP * vec2(1.5, 1.0)) - 0.12;
    float legs = max(smoothstep(0.02, 0.0, -legL), smoothstep(0.02, 0.0, -legR));
    color = mix(color, frogColor * 0.9, legs);
    
    // Fog
    float fog = smoothstep(2.0, 0.5, length(p));
    vec3 fogColor = mix(vec3(0.4, 0.6, 0.7), vec3(0.9, 0.6, 0.4), smoothstep(-0.5, 0.5, sunHeight));
    color = mix(color, fogColor, fog * 0.3);
    
    color *= intensity;
    return vec4(color, alpha);
}