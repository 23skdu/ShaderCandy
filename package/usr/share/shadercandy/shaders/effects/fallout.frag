#include "base/common.glsl"

// fallout - Vault-Tec Terminal aesthetic with CRT effects

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Background - dark green/black
    vec3 color = vec3(0.02, 0.04, 0.02);
    
    // Monitor frame
    vec2 monitorSize = vec2(1.6, 1.2);
    vec2 frameP = p;
    float frameDist = max(abs(frameP.x) - monitorSize.x * 0.5, abs(frameP.y) - monitorSize.y * 0.5);
    if (frameDist > 0.0 && frameDist < 0.1) {
        color = vec3(0.25, 0.28, 0.25);
    }
    
    // Screen area
    vec2 screenP = (p + vec2(0.8, 0.6)) / vec2(1.6, 1.2);
    if (screenP.x > 0.0 && screenP.x < 1.0 && screenP.y > 0.0 && screenP.y < 1.0) {
        // CRT screen glow
        vec3 screenBase = vec3(0.0, 0.3, 0.1);
        
        // Scanlines
        float scan = sin(screenP.y * 400.0 + t * 10.0) * 0.1 + 0.9;
        
        // Curvature effect (darker at edges)
        float curv = 1.0 - length(screenP - 0.5) * 0.3;
        
        // Random "text" noise
        float textNoise = fract(sin(dot(floor(screenP * vec2(30.0, 50.0)) + floor(t * 2.0), vec2(12.9898, 78.233))) * 43758.5453);
        float text = step(0.7, textNoise);
        
        // Vault-Tec logo (circle with lightning)
        float distToCenter = length(screenP - 0.5);
        float logo = smoothstep(0.15, 0.14, distToCenter);
        float lightning = (0.5 + 0.5 * sin(atan(screenP.y - 0.5, screenP.x - 0.5) * 8.0));
        logo *= lightning;
        
        // Combine screen content
        vec3 screenCol = screenBase * (text * 0.3 + logo * 0.9 + 0.15) * scan * curv;
        
        // Screen flicker
        screenCol *= 0.95 + 0.05 * sin(t * 60.0);
        
        // Phosphor glow
        screenCol += screenCol * 0.4;
        
        color = mix(color, screenCol, 0.95);
    }
    
    // Stand
    vec2 standP = p - vec2(0.0, -0.9);
    float standDist = length(standP * vec2(1.0, 0.3));
    if (standDist < 0.25 && standDist > 0.15) {
        color = vec3(0.2, 0.22, 0.2);
    }
    
    // Screen edge glow/bloom
    if (screenP.x > 0.0 && screenP.x < 1.0 && screenP.y > 0.0 && screenP.y < 1.0) {
        float edgeGlow = smoothstep(0.0, 0.1, min(min(screenP.x, 1.0 - screenP.x), min(screenP.y, 1.0 - screenP.y)));
        color *= edgeGlow * 0.3 + 0.7;
    }
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.4;
    
    color *= intensity;
    return vec4(color, alpha);
}