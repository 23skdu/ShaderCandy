#include "base/common.glsl"

// mind_palace - Infinite shifting architectural rooms

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
    
    vec3 color = vec3(0.02, 0.02, 0.05);
    
    // Grid pattern representing infinite rooms
    vec2 room = fract(p * 2.0) - 0.5;
    vec2 roomId = floor(p * 2.0);
    
    // Room frame (archway)
    float frameDist = max(abs(room.x), abs(room.y));
    float frame = smoothstep(0.48, 0.45, frameDist) - smoothstep(0.45, 0.42, frameDist);
    
    // Glowing edges
    float glow = smoothstep(0.5, 0.4, frameDist);
    
    // Hieroglyphs / symbols that appear/disappear
    float symbolPhase = fract(t * 0.2 + roomId.x * 0.3 + roomId.y * 0.2);
    float symbol = step(0.4, symbolPhase) * step(symbolPhase, 0.7);
    
    // Cross beams
    for (float i = 0.0; i < 3.0; i++) {
        float beamPhase = fract(t * 0.15 + i * 0.3);
        float beam = step(0.3, beamPhase) * step(beamPhase, 0.7);
        
        // Horizontal beams
        float hBeam = smoothstep(0.02, 0.0, abs(room.y - (i - 1.0) * 0.3)) * beam;
        color += hsv2rgb(vec3(fract(t * 0.1 + i * 0.2), 0.8, 1.0)) * hBeam * 0.3;
        
        // Vertical beams
        float vBeam = smoothstep(0.02, 0.0, abs(room.x - (i - 1.0) * 0.3)) * beam;
        color += hsv2rgb(vec3(fract(t * 0.15 + i * 0.2), 0.7, 1.0)) * vBeam * 0.3;
    }
    
    // Room color with symbol
    vec3 roomColor = hsv2rgb(vec3(fract(roomId.x * 0.1 + roomId.y * 0.07 + t * 0.05), 0.6, 0.8));
    color += roomColor * frame * 0.4;
    
    // Symbols
    if (symbol > 0.5 && frame > 0.1) {
        vec2 symbolPos = room * 10.0;
        float s = step(0.5, fract(sin(dot(floor(symbolPos), vec2(12.9898, 78.233))) * 43758.5453));
        color += vec3(1.0, 0.9, 0.5) * s * symbol * 0.5;
    }
    
    // Glow
    color += roomColor * glow * 0.2;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}