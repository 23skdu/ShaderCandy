#include "base/common.glsl"

// thieves - Dark alley with treasure chest and gold coins

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.02, 0.02, 0.05);
    
    // Brick walls (top portion)
    if (p.y > -0.3) {
        vec2 brickUV = p * vec2(8.0, 12.0);
        vec2 brickId = floor(brickUV);
        vec2 brickUVf = fract(brickUV);
        
        // Offset every other row
        if (mod(brickId.y, 2.0) > 0.5) {
            brickUVf.x += 0.5;
        }
        
        // Brick pattern
        float brick = step(0.05, brickUVf.x) * step(brickUVf.x, 0.95);
        brick *= step(0.1, brickUVf.y) * step(brickUVf.y, 0.9);
        
        // Brick color variation
        float brickVar = fract(sin(dot(brickId, vec2(127.1, 311.7))) * 43758.5453);
        vec3 brickColor = mix(vec3(0.08, 0.07, 0.06), vec3(0.12, 0.1, 0.08), brickVar);
        
        // Mortar
        vec3 mortarColor = vec3(0.04, 0.04, 0.04);
        color = mix(mortarColor, brickColor, brick);
        
        // Add some noise/texture
        float noiseTex = noise(p * 50.0);
        color *= 0.9 + 0.2 * noiseTex;
    }
    
    // Ground (dark cobblestone)
    if (p.y < -0.3) {
        vec2 stoneUV = p * 10.0;
        vec2 stoneId = floor(stoneUV);
        vec2 stoneUVf = fract(stoneUV);
        
        float stone = step(0.02, stoneUVf.x) * step(stoneUVf.x, 0.98);
        stone *= step(0.02, stoneUVf.y) * step(stoneUVf.y, 0.98);
        
        float stoneVar = fract(sin(dot(stoneId, vec2(127.1, 311.7))) * 43758.5453);
        vec3 stoneColor = mix(vec3(0.05, 0.05, 0.05), vec3(0.08, 0.07, 0.06), stoneVar);
        
        color = mix(color, stoneColor, stone);
    }
    
    // Lantern light (dim, warm)
    vec2 lanternPos = vec2(0.5, -0.1);
    float lanternDist = length(p - lanternPos);
    float lanternLight = 1.0 / (1.0 + lanternDist * 2.0);
    lanternLight *= smoothstep(0.8, 0.0, lanternDist);
    
    vec3 lanternColor = vec3(1.0, 0.6, 0.2);
    color += lanternColor * lanternLight * 0.5;
    
    // Treasure chest
    vec2 chestPos = vec2(-0.3, -0.65);
    vec2 chestP = p - chestPos;
    
    // Chest body
    float chestBody = max(abs(chestP.x) - 0.25, abs(chestP.y + 0.05) - 0.12);
    chestBody = smoothstep(0.02, 0.0, -chestBody);
    
    // Chest lid
    float chestLid = max(abs(chestP.x) - 0.22, abs(chestP.y - 0.1) - 0.06);
    chestLid = smoothstep(0.02, 0.0, -chestLid);
    
    // Chest details (lock, bands)
    float lock = smoothstep(0.03, 0.02, length(chestP - vec2(0.0, 0.02)));
    float bandV = smoothstep(0.01, 0.0, abs(mod(chestP.x + 0.15, 0.3) - 0.15));
    bandV *= smoothstep(0.15, 0.0, abs(chestP.y + 0.05));
    
    vec3 chestColor = vec3(0.35, 0.18, 0.08);
    color = mix(color, chestColor, chestBody);
    color = mix(color, chestColor * 1.2, chestLid);
    color = mix(color, vec3(0.2, 0.15, 0.05), lock);
    color = mix(color, vec3(0.25, 0.15, 0.05), bandV);
    
    // Gold coins (scattered around chest)
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float coinX = -0.5 + sin(fi) * 0.3;
        float coinY = -0.75 + cos(fi) * 0.1;
        
        vec2 coinP = p - vec2(coinX, coinY);
        float coin = smoothstep(0.06, 0.04, length(coinP));
        
        // Sparkle
        float sparkle = 0.5 + 0.5 * sin(t * 3.0 + fi * 2.0);
        vec3 coinColor = vec3(1.0, 0.85, 0.3) * (0.8 + 0.2 * sparkle);
        
        color = mix(color, coinColor, coin);
    }
    
    // Vignette effect (dark corners)
    float vignette = smoothstep(1.5, 0.3, length(p));
    color *= vignette;
    
    color *= intensity;
    return vec4(color, alpha);
}