#include "base/common.glsl"

// starship_hud - Tactical starship cockpit display

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.0);
    
    // Background: Moving Starfield
    vec3 pos = vec3(p * 2.0, 1.0);
    for(float i = 0.0; i < 4.0; i++) {
        float f = fract(t * 0.1 + i * 0.25);
        vec2 startUV = p * (1.0 / (f + 0.01));
        float starScale = 10.0 + i * 5.0;
        float s = pow(noise(startUV * starScale), 20.0) * (1.0 - f);
        color += s * vec3(0.8, 0.9, 1.0);
    }
    
    // HUD Overlay: Crosshair
    float cross = smoothstep(0.01, 0.0, abs(p.x)) * smoothstep(0.2, 0.0, abs(p.y));
    cross += smoothstep(0.01, 0.0, abs(p.y)) * smoothstep(0.2, 0.0, abs(p.x));
    float circle = exp(-abs(length(p) - 0.4) * 40.0);
    
    vec3 hudCol = vec3(0.1, 1.0, 0.4);
    color += hudCol * (cross + circle) * 0.6;
    
    // Tactical Bracket
    vec2 targetPos = vec2(cos(t * 0.5) * 0.6, sin(t * 0.7) * 0.4);
    vec2 bracketUV = abs(p - targetPos);
    if (bracketUV.x < 0.15 && bracketUV.y < 0.15) {
        float edge = step(0.14, max(bracketUV.x, bracketUV.y));
        color += vec3(1.0, 0.2, 0.2) * edge * (0.5 + 0.5 * sin(t * 15.0));
    }
    
    // Scanlines & Digital Noise
    float scanline = sin(uv.y * 200.0) * 0.05;
    color += scanline;
    if (hash(vec2(t, t)) > 0.98) color += 0.05 * noise(p * 50.0);
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.4;
    
    color *= intensity;
    return vec4(color, alpha);
}