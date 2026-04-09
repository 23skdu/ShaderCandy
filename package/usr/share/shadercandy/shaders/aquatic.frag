#include "base/common.glsl"

// aquatic - Underwater scene with caustics, bubbles, and fish

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.0);
    
    // Deep water background gradient
    vec3 deepColor = mix(vec3(0.0, 0.1, 0.25), vec3(0.0, 0.02, 0.1), 0.8);
    color = deepColor;
    
    // Far layer - fish silhouettes
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float fishDepth = fract(fi * 0.4 + 0.8 * 0.3);
        
        vec2 fishPos = p;
        fishPos.x += t * (0.2 + fishDepth * 0.1) + fi * 0.8;
        fishPos.x = mod(fishPos.x + 2.0, 4.0) - 2.0;
        fishPos.y += sin(t * 2.0 + fi * 3.0) * 0.1 * (1.0 + fishDepth);
        
        float fishBody = smoothstep(0.15, 0.12, length(vec2(fishPos.x * 2.0, fishPos.y)));
        vec2 tailOffset = vec2(-0.12, sin(t * 10.0 + fi) * 0.02);
        float fishTail = smoothstep(0.08, 0.05, length(fishPos - tailOffset));
        
        float fish = max(fishBody, fishTail * 0.7);
        
        vec3 fishColor = vec3(0.05, 0.1, 0.15);
        color += fishColor * fish * 0.5;
    }
    
    // Caustics (far layer - dim)
    float caustic1 = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        vec2 offset = vec2(sin(t * (1.0 + fi * 0.3) + fi * 2.0), cos(t * (0.8 + fi * 0.2) + fi * 1.5)) * 0.3;
        caustic1 += sin((p.x + offset.x) * (15.0 + fi * 5.0) + t * (3.0 + fi));
        caustic1 *= sin((p.y + offset.y) * (12.0 + fi * 4.0) + t * (2.5 + fi * 0.5));
    }
    caustic1 = smoothstep(0.3, 0.7, caustic1 * 0.5 + 0.5);
    color += vec3(1.0, 0.9, 0.7) * caustic1 * 0.15;
    
    // Middle layer - more bubbles
    for (float i = 0.0; i < 8.0; i++) {
        float fi = i;
        float bubbleDepth = fract(fi * 0.618 + 0.5 * 0.5);
        float speed = 0.5 + bubbleDepth * 0.5;
        float size = 0.02 + bubbleDepth * 0.03;
        
        vec2 bubbleP = p;
        bubbleP.y += t * speed * (0.3 + bubbleDepth * 0.2);
        bubbleP.y = fract(bubbleP.y + fi * 0.3 + 0.5) - 0.5;
        bubbleP.x += sin(t * 0.5 + fi * 3.0) * 0.1 * (1.0 + bubbleDepth);
        
        float2 gridPos = vec2(mod(fi * 0.7 + sin(fi * 2.0) * 0.5, 2.0) - 1.0, 0.0);
        bubbleP -= gridPos * (0.5 + bubbleDepth * 0.5);
        
        float dist = length(bubbleP);
        float bubble = smoothstep(size, size * 0.7, dist);
        
        float highlight = smoothstep(size * 0.3, size * 0.1, length(bubbleP - vec2(-size * 0.3, size * 0.3)));
        
        vec3 bubbleColor = mix(vec3(0.6, 0.7, 0.9), vec3(0.8, 0.9, 1.0), bubbleDepth);
        color += bubbleColor * bubble * 0.4;
        color += vec3(1.0) * highlight * bubble * 0.3;
    }
    
    // Caustics (middle layer)
    float caustic2 = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        vec2 offset = vec2(sin(t * (1.0 + fi * 0.3) + fi * 2.0 + 0.3), cos(t * (0.8 + fi * 0.2) + fi * 1.5)) * 0.3;
        caustic2 += sin((p.x + offset.x) * (15.0 + fi * 5.0) + t * (3.0 + fi));
        caustic2 *= sin((p.y + offset.y) * (12.0 + fi * 4.0) + t * (2.5 + fi * 0.5));
    }
    caustic2 = smoothstep(0.3, 0.7, caustic2 * 0.5 + 0.5);
    color += vec3(1.0, 0.9, 0.7) * caustic2 * 0.25;
    
    // Near layer - more caustics and bubbles
    float caustic3 = 0.0;
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        vec2 offset = vec2(sin(t * (1.0 + fi * 0.3) + fi * 2.0 + 0.7), cos(t * (0.8 + fi * 0.2) + fi * 1.5)) * 0.3;
        caustic3 += sin((p.x + offset.x) * (15.0 + fi * 5.0) + t * (3.0 + fi));
        caustic3 *= sin((p.y + offset.y) * (12.0 + fi * 4.0) + t * (2.5 + fi * 0.5));
    }
    caustic3 = smoothstep(0.3, 0.7, caustic3 * 0.5 + 0.5);
    color += vec3(1.0, 0.9, 0.7) * caustic3 * 0.35;
    
    // Near bubbles
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        vec2 bubbleP = p;
        bubbleP.y += t * 0.8 + fi * 0.3;
        bubbleP.y = fract(bubbleP.y) - 0.5;
        bubbleP.x += sin(t * 0.5 + fi * 2.0) * 0.15;
        
        float size = 0.03 + fi * 0.005;
        float bubble = smoothstep(size, size * 0.7, length(bubbleP));
        
        color += vec3(0.9, 0.95, 1.0) * bubble * 0.5;
    }
    
    // Surface wave effect
    float wave = sin(p.x * 10.0 + t * 3.0) * 0.5 + 0.5;
    wave *= sin(p.y * 8.0 + t * 2.0) * 0.5 + 0.5;
    color += vec3(0.0, 0.1, 0.2) * wave * 0.1;
    
    // Deep water vignette
    float vignette = 1.0 - length(p) * 0.4;
    color *= vignette;
    
    // Blue overlay
    vec3 deepBlue = vec3(0.0, 0.05, 0.15);
    color = mix(color, deepBlue, 0.2);
    
    color *= intensity;
    return vec4(color, alpha);
}