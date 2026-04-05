#include "base/common.glsl"

// reggae - Tropical Jamaican flag with sun and palm trees

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Wave effect for the flag
    float wave = sin(uv.x * 4.0 - t * 3.0) * 0.1 * (uv.x + 0.1);
    float waveY = sin(uv.y * 2.0 - t * 2.0) * 0.05;
    vec2 wuv = uv + vec2(0.0, wave + waveY);
    
    vec3 color = vec3(0.0, 0.2, 0.4); // Deep blue ocean
    
    // Sun
    float sun = smoothstep(0.4, 0.38, length(p - vec2(0.8, 0.6)));
    color = mix(color, vec3(1.0, 0.9, 0.2), sun);
    
    // Flag area (Jamaican flag: gold center, green top, black bottom)
    if (wuv.y > 0.2 && wuv.y < 0.8 && wuv.x > 0.1 && wuv.x < 0.9) {
        vec3 flagCol;
        if (wuv.y > 0.6) {
            flagCol = vec3(0.1, 0.6, 0.1); // Green top
        } else if (wuv.y > 0.4) {
            flagCol = vec3(0.0, 0.0, 0.0); // Black center
        } else {
            flagCol = vec3(1.0, 0.8, 0.0); // Gold bottom
        }
        
        // Shading based on waves
        float shading = 1.0 + (wave + waveY) * 5.0;
        color = flagCol * shading;
        
        // Fabric texture
        float tex = noise(wuv * 200.0);
        color *= (0.9 + 0.1 * tex);
    }
    
    // Palm tree silhouette
    vec2 palmP = p - vec2(-0.8, -0.3);
    float palmAngle = atan(palmP.y, palmP.x);
    float palmRad = length(palmP);
    
    // Palm trunk
    float trunk = smoothstep(0.08, 0.05, abs(palmP.x + 0.05));
    trunk *= smoothstep(-0.3, 0.3, palmP.y) * smoothstep(1.2, 0.5, palmP.y);
    
    // Palm leaves (spiky radial pattern)
    float leaves = 0.0;
    for (float i = 0.0; i < 8.0; i++) {
        float fi = i;
        float leafAngle = fi * 0.785 + 0.3; // 8 evenly spaced
        vec2 leafDir = vec2(cos(leafAngle), sin(leafAngle));
        float leafDist = dot(palmP, leafDir);
        float leafPerp = length(palmP - leafDir * leafDist);
        float leaf = smoothstep(0.15, 0.05, leafPerp) * smoothstep(0.0, 0.3, leafDist) * smoothstep(1.0, 0.4, leafDist);
        leaves = max(leaves, leaf);
    }
    
    float palm = max(trunk, leaves);
    color = mix(color, vec3(0.02, 0.05, 0.02), palm * smoothstep(1.5, 0.0, palmRad));
    
    // Second smaller palm on right
    vec2 palmP2 = p - vec2(1.0, -0.2);
    float palm2 = smoothstep(0.05, 0.02, length(palmP2 - vec2(0.0, 0.5)));
    palm2 *= smoothstep(0.8, 0.3, length(palmP2));
    color = mix(color, vec3(0.02, 0.05, 0.02), palm2 * 0.8);
    
    // Audio reactivity - flag waves more with bass
    float bassWave = wave * (1.0 + bass * 0.5);
    color *= (1.0 + bass * 0.1);
    
    color *= intensity;
    return vec4(color, alpha);
}