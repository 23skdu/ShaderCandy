#include "base/common.glsl"

// dragon - Monster eye with scales and fire glow

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Blink animation
    float blinkPhase = fract(t * 0.3);
    float blink = 0.0;
    if (blinkPhase < 0.1) {
        blink = sin(blinkPhase / 0.1 * 3.14159);
    }
    
    vec3 color = vec3(0.0);
    
    // Dragon scales background
    vec2 scaleUV = p + vec2(sin(t * 0.1) * 0.05, cos(t * 0.15) * 0.05);
    vec2 scaleId = floor(scaleUV * 10.0);
    vec2 scaleGV = fract(scaleUV * 10.0) - 0.5;
    
    float scaleD = length(scaleGV + vec2(0.1) * sin(scaleId.y * 2.0 + scaleId.x + t * 0.5));
    float scalePattern = smoothstep(0.4, 0.3, scaleD);
    
    vec3 scaleCol = mix(vec3(0.03, 0.08, 0.04), vec3(0.08, 0.15, 0.08), scalePattern);
    
    // Eye socket shadow
    float eyeSocket = length(p) - 0.7;
    eyeSocket = smoothstep(0.0, 0.3, eyeSocket);
    scaleCol *= eyeSocket;
    
    color = scaleCol;
    
    // Eye (2D approximation)
    float eyeDist = length(p);
    
    if (eyeDist < 0.5 + blink * 0.1) {
        // Iris
        float irisDist = length(p);
        
        if (irisDist < 0.25) {
            // Iris - fiery orange/red
            float angle = atan(p.y, p.x);
            float irisPattern = sin(angle * 8.0 + t) * sin(irisDist * 20.0);
            vec3 irisBase = mix(vec3(0.9, 0.3, 0.0), vec3(0.8, 0.1, 0.0), 0.5 + irisPattern * 0.5);
            
            // Noise variation
            float n = noise(vec2(p.x * 5.0, p.y * 5.0) + t * 0.2);
            irisBase = mix(irisBase, irisBase * 0.7, n * 0.5);
            
            color = irisBase;
            
            // Specular highlight
            vec2 lightDir = normalize(vec2(1.0, 1.0));
            float spec = pow(max(0.0, dot(normalize(p), lightDir)), 32.0);
            color += vec3(1.0, 0.5, 0.0) * spec * 0.5;
        } else if (irisDist < 0.35) {
            // Sclera (white with veins)
            vec3 scleraCol = vec3(0.9, 0.95, 0.85);
            float vein = noise(p * 10.0 + t * 0.1);
            scleraCol = mix(scleraCol, vec3(0.8, 0.3, 0.2), smoothstep(0.6, 0.8, vein) * 0.3);
            color = scleraCol;
        }
        
        // Pupil (black center)
        if (irisDist < 0.12) {
            color = vec3(0.0, 0.0, 0.02);
            // Small reflection
            vec2 lightDir = normalize(vec2(1.0, 1.0));
            float reflect = pow(max(0.0, dot(normalize(p), lightDir)), 64.0);
            color += vec3(0.1, 0.05, 0.0) * reflect;
        }
    }
    
    // Eyelids (when blinking)
    if (blink > 0.0) {
        float upperLid = smoothstep(0.3, 0.5, p.y) * smoothstep(0.6, 0.4, p.y);
        float lowerLid = smoothstep(-0.3, -0.5, p.y) * smoothstep(-0.6, -0.4, p.y);
        float eyelid = max(upperLid, lowerLid);
        
        vec3 lidColor = vec3(0.04, 0.1, 0.05);
        color = mix(color, lidColor, eyelid * blink);
    }
    
    // Eye socket blend
    float eyeBlend = smoothstep(0.65, 0.0, length(p));
    color = mix(scaleCol, color, eyeBlend);
    
    // Fire glow around eye
    float firePulse = 0.8 + 0.2 * sin(t * 3.0);
    float eyeGlow = 0.15 / (length(p) + 0.15);
    color += vec3(1.0, 0.2 + blink * 0.3, 0.0) * eyeGlow * firePulse;
    
    // Embers/sparks
    for (float i = 0.0; i < 8.0; i++) {
        float fi = i;
        vec2 sparkPos = p + vec2(
            sin(t * 2.0 + fi * 2.0) * (0.5 + fi * 0.1),
            cos(t * 1.5 + fi * 1.5) * (0.3 + fi * 0.08) + t * 0.2
        );
        float spark = smoothstep(0.03, 0.0, length(sparkPos));
        color += vec3(1.0, 0.4, 0.0) * spark * (0.5 + 0.5 * sin(t * 5.0 + fi));
    }
    
    color *= intensity;
    return vec4(color, alpha);
}