#include "base/common.glsl"

// 8bit - Retro 8-bit platformer scene (GLSL version)

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    
    // Pixelate
    float pixelSize = 64.0;
    vec2 pixelUV = floor(uv * pixelSize) / pixelSize;
    vec2 p = (pixelUV - 0.5) * 2.0;
    p.x *= resolution.x / resolution.y;
    
    // Sky gradient
    vec3 col = mix(vec3(0.3, 0.6, 1.0), vec3(0.5, 0.8, 1.0), uv.y);
    
    // Scrolling clouds
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 cloudPos = p;
        cloudPos.x += t * 0.2 + fi * 1.5;
        cloudPos.x = mod(cloudPos.x + 2.0, 4.0) - 2.0;
        cloudPos.y += 0.3 + fi * 0.1;
        
        float cloud = 0.0;
        cloud += smoothstep(0.15, 0.0, length(cloudPos));
        cloud += smoothstep(0.1, 0.0, length(cloudPos + vec2(0.12, 0.0)));
        cloud += smoothstep(0.1, 0.0, length(cloudPos + vec2(-0.12, 0.0)));
        cloud = step(0.5, cloud);
        
        col = mix(col, vec3(1.0), cloud * 0.8);
    }
    
    // Ground
    float ground = step(-0.35, p.y);
    vec3 groundCol = vec3(0.2, 0.7, 0.2);
    col = mix(groundCol, col, ground);
    
    // Question blocks
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 blockPos = p;
        blockPos.x += fi * 0.6 - 0.6;
        blockPos.y += 0.2 + sin(t * 2.0 + fi) * 0.03;
        
        float block = step(abs(blockPos.x), 0.12) * step(abs(blockPos.y), 0.12);
        vec3 blockCol = vec3(0.9, 0.7, 0.3);
        col = mix(col, blockCol, block);
    }
    
    // Coins
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 coinP = p - vec2(-0.8 + fi * 0.4, sin(t * 3.0 + fi * 1.5) * 0.15);
        float coin = smoothstep(0.06, 0.05, length(coinP));
        col = mix(col, vec3(1.0, 0.85, 0.2), coin);
    }
    
    // Enemies
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 enemyP = p;
        enemyP.x = mod(enemyP.x + t * 0.8 + fi * 0.5 + 0.5, 3.0) - 1.5;
        enemyP.y = -0.35;
        
        float enemy = step(length(enemyP - vec2(0.0, 0.0)), 0.1);
        col = mix(col, vec3(0.6, 0.4, 0.2), enemy * ground);
    }
    
    // Scanlines
    float scanline = sin(uv.y * pixelSize * 3.14159) * 0.5 + 0.5;
    col *= mix(0.85, 1.0, scanline);
    
    col *= intensity;
    return vec4(col, alpha);
}
