#include "base/common.glsl"

// knights - Chess board with knight pieces

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.1, 0.1, 0.15);
    
    // Checkerboard floor
    float boardY = -0.4;
    if (p.y < boardY + 0.1) {
        vec2 boardP = p - vec2(0.0, boardY);
        vec2 checkerUV = boardP * 2.5;
        vec2 checkerId = floor(checkerUV);
        float checker = mod(checkerId.x + checkerId.y, 2.0);
        
        vec3 lightSquare = vec3(0.8, 0.75, 0.7);
        vec3 darkSquare = vec3(0.15, 0.12, 0.1);
        color = mix(darkSquare, lightSquare, checker);
    }
    
    // First knight (black/dark - left side)
    vec2 knight1Pos = vec2(-0.5, 0.0);
    float knight1Angle = t * 0.5;
    vec2 k1P = p - knight1Pos;
    k1P = vec2(k1P.x * cos(knight1Angle) - k1P.y * sin(knight1Angle),
                k1P.x * sin(knight1Angle) + k1P.y * cos(knight1Angle));
    
    // Base
    float base1 = max(abs(k1P.x) - 0.2, abs(k1P.y + 0.15) - 0.08);
    // Body
    float body1 = length(k1P - vec2(0.0, 0.1)) - 0.15;
    // Horse head
    float head1 = length(k1P - vec2(0.15, 0.25)) - 0.12;
    float snout1 = length(k1P - vec2(0.28, 0.18)) - 0.08;
    
    float knight1 = smoothstep(0.02, 0.0, -base1);
    knight1 = max(knight1, smoothstep(0.02, 0.0, -body1));
    knight1 = max(knight1, smoothstep(0.02, 0.0, -head1));
    knight1 = max(knight1, smoothstep(0.02, 0.0, -snout1));
    
    vec3 knight1Color = vec3(0.1, 0.05, 0.02);
    color = mix(color, knight1Color, knight1);
    
    // Second knight (white - right side)
    vec2 knight2Pos = vec2(0.7, 0.3);
    float knight2Angle = -t * 0.7;
    vec2 k2P = p - knight2Pos;
    k2P = vec2(k2P.x * cos(knight2Angle) - k2P.y * sin(knight2Angle),
                k2P.x * sin(knight2Angle) + k2P.y * cos(knight2Angle));
    
    // Base
    float base2 = max(abs(k2P.x) - 0.2, abs(k2P.y + 0.15) - 0.08);
    // Body
    float body2 = length(k2P - vec2(0.0, 0.1)) - 0.15;
    // Horse head
    float head2 = length(k2P - vec2(0.15, 0.25)) - 0.12;
    float snout2 = length(k2P - vec2(0.28, 0.18)) - 0.08;
    
    float knight2 = smoothstep(0.02, 0.0, -base2);
    knight2 = max(knight2, smoothstep(0.02, 0.0, -body2));
    knight2 = max(knight2, smoothstep(0.02, 0.0, -head2));
    knight2 = max(knight2, smoothstep(0.02, 0.0, -snout2));
    
    vec3 knight2Color = vec3(0.9, 0.88, 0.85);
    color = mix(color, knight2Color, knight2);
    
    // Lighting
    vec3 lightPos = vec2(1.0, 1.5);
    float diff = 0.3 + 0.7 * max(0.0, 1.0 - length(p - lightPos) * 0.3);
    color *= diff;
    
    // Glow/bloom effect
    float glow = 0.15 * (1.0 - length(p) * 0.5);
    color += vec3(0.1, 0.1, 0.2) * glow;
    
    // Vignette
    color *= smoothstep(1.5, 0.5, length(p));
    
    color *= intensity;
    return vec4(color, alpha);
}