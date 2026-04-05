#include "base/common.glsl"

// owl - Night scene with owls on branches

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = mix(vec3(0.02, 0.02, 0.08), vec3(0.05, 0.05, 0.15), uv.y);
    
    // Stars
    for (float i = 0.0; i < 50.0; i++) {
        float fi = i;
        vec2 starPos = vec2(fract(fi * 0.37 + 0.13) * 4.0 - 2.0, fract(fi * 0.23 + 0.07) * 2.0 - 1.0);
        float starSize = 0.003 + fract(fi * 0.19) * 0.003;
        float star = smoothstep(starSize, 0.0, length(p - starPos));
        float twinkle = 0.5 + 0.5 * sin(t * 2.0 + fi * 3.0);
        color += vec3(0.9, 0.95, 1.0) * star * twinkle;
    }
    
    // Moon
    vec2 moonPos = vec2(0.6, 0.7);
    float moonDist = length(p - moonPos);
    float moon = smoothstep(0.12, 0.11, moonDist);
    color += vec3(0.95, 0.95, 0.9) * moon;
    
    // Tree branch (horizontal)
    float branchY = -0.5;
    float branch = smoothstep(0.08, 0.05, abs(p.y - branchY));
    branch *= smoothstep(-1.5, -0.5, p.x) * smoothstep(1.5, 0.5, p.x);
    vec3 branchColor = vec3(0.15, 0.1, 0.06);
    color = mix(color, branchColor, branch);
    
    // Draw 3 owls on branch
    vec2 owlPositions[3];
    owlPositions[0] = vec2(0.0, branchY + 0.15);
    owlPositions[1] = vec2(-1.2, branchY + 0.18);
    owlPositions[2] = vec2(1.3, branchY + 0.12);
    
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        vec2 owlPos = owlPositions[int(fi)];
        vec2 owlP = p - owlPos;
        
        // Head rotation animation
        float headRot = sin(t * 0.5 + fi * 2.0) * 0.15;
        owlP.x += headRot;
        
        // Body (oval)
        float body = length(owlP * vec2(0.7, 1.0)) - 0.18;
        
        // Head (circle)
        vec2 headP = owlP - vec2(0.0, 0.22);
        float head = length(headP) - 0.15;
        
        // Ear tufts
        float tuftL = length(owlP - vec2(-0.1, 0.35)) - 0.06;
        float tuftR = length(owlP - vec2(0.1, 0.35)) - 0.06;
        
        // Eyes (glowing)
        vec2 eyeLP = headP - vec2(-0.07, 0.02);
        vec2 eyeRP = headP - vec2(0.07, 0.02);
        float eyeL = length(eyeLP) - 0.06;
        float eyeR = length(eyeRP) - 0.06;
        
        // Beak
        float beak = length(headP - vec2(0.0, -0.08)) - 0.04;
        
        // Combine owl parts
        float owl = smoothstep(0.01, 0.0, -body);
        owl = max(owl, smoothstep(0.01, 0.0, -head));
        owl = max(owl, smoothstep(0.01, 0.0, -tuftL));
        owl = max(owl, smoothstep(0.01, 0.0, -tuftR));
        
        // Eye color (glowing golden)
        float eyes = smoothstep(0.01, 0.0, -eyeL);
        eyes = max(eyes, smoothstep(0.01, 0.0, -eyeR));
        
        // Beak color
        float beakCol = smoothstep(0.01, 0.0, -beak);
        
        // Owl color (brown)
        vec3 owlColor = vec3(0.25, 0.2, 0.15);
        
        // Belly (lighter)
        if (owlP.y < -0.05 && abs(owlP.x) < 0.12) {
            owlColor = vec3(0.4, 0.35, 0.28);
        }
        
        // Facial disc (lighter face)
        if (headP.y > 0.0 && length(headP.xy) < 0.12) {
            owlColor = vec3(0.35, 0.3, 0.22);
        }
        
        color = mix(color, owlColor, owl);
        
        // Eyes glow
        color = mix(color, vec3(1.0, 0.85, 0.1), eyes * 0.8);
        
        // Pupils
        float pupilL = length(eyeLP) - 0.025;
        float pupilR = length(eyeRP) - 0.025;
        float pupil = smoothstep(0.005, 0.0, -pupilL);
        pupil = max(pupil, smoothstep(0.005, 0.0, -pupilR));
        color = mix(color, vec3(0.0), pupil);
        
        // Beak
        color = mix(color, vec3(0.15, 0.1, 0.05), beakCol);
    }
    
    // Vignette
    color *= smoothstep(1.5, 0.5, length(p));
    
    color *= intensity;
    return vec4(color, alpha);
}