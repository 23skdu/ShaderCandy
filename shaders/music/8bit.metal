// 8Bit - Retro pixel art aesthetic like classic video games

#include <metal_stdlib>
using namespace metal;

/* struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float speed;
    float intensity;
    float bass;
    float mid;
    float treble;
}; */


// Pixelate coordinates
float2 pixelate(float2 uv, float pixels) {
    return floor(uv * pixels) / pixels;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                                 constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.5;
    
    // Pixel size (lower = chunkier pixels)
    float pixelSize = 64.0;
    float2 pixelUV = pixelate(uv, pixelSize);
    float2 pixelP = pixelate(p, pixelSize / 2.0);
    
    // Sky - classic blue
    float3 col = float3(0.4, 0.6, 1.0);
    
    // Scrolling clouds (Mario-style)
    float2 cloudP = pixelP;
    cloudP.x += t * 0.3;
    float cloud = step(0.5, fract(cloudP.x * 3.0 + 0.5));
    cloud *= step(0.4, fract(cloudP.y * 2.0 + 0.5));
    cloud *= step(0.3, pixelUV.y);  // Only in upper sky
    col = mix(col, float3(1.0), cloud * 0.8);
    
    // Ground hills (green)
    float ground = smoothstep(-0.3, -0.2, pixelP.y);
    float3 groundCol = float3(0.2, 0.7, 0.2);
    // Add detail to ground
    float groundDetail = step(0.5, fract(pixelP.x * 8.0 + pixelP.y * 4.0));
    groundCol = mix(groundCol, float3(0.15, 0.5, 0.15), groundDetail * 0.3);
    col = mix(groundCol, col, ground);
    
    // Ground line
    float groundLine = smoothstep(-0.28, -0.3, pixelP.y) * smoothstep(-0.32, -0.3, pixelP.y);
    col = mix(col, float3(0.6, 0.3, 0.1), groundLine);  // Brown dirt
    
    // Question blocks (Mario style)
    float2 blockP = pixelP;
    blockP.x += 0.5;
    blockP.y = mod(blockP.y + t * 0.5, 1.0) - 0.5;
    float2 blockGrid = floor(blockP * float2(4.0, 3.0));
    
    float blockMask = 0.0;
    if (abs(blockGrid.x) < 1.0 && abs(blockGrid.y) < 1.0) {
        float2 localP = fract(blockP * float2(4.0, 3.0)) - 0.5;
        blockMask = step(abs(localP.x), 0.4) * step(abs(localP.y), 0.4);
        
        // Question mark pattern
        float2 qP = fract(blockP * float2(4.0, 3.0));
        float qMark = step(0.3, qP.x) * step(qP.x, 0.7) * step(0.4, qP.y) * step(qP.y, 0.6);
        qMark += step(0.4, qP.x) * step(qP.x, 0.6) * step(0.3, qP.y) * step(qP.y, 0.35);
        qMark += step(0.35, qP.y) * step(qP.y, 0.45) * step(0.4, qP.x) * step(qP.x, 0.6);
        
        float3 blockCol = float3(0.9, 0.7, 0.3);  // Gold block
        blockCol = mix(blockCol, float3(0.8, 0.2, 0.1), step(0.5, qMark));  // Red for question
        col = mix(col, blockCol, blockMask);
        col = mix(col, float3(0.1), blockMask * qMark * 0.5);
    }
    
    // Goomba-like enemies
    float2 enemyP = pixelP;
    enemyP.x = mod(enemyP.x + t * 0.8 + 0.5, 2.0) - 1.0;
    enemyP.y = smoothstep(-0.1, 0.0, sin(t * 5.0 + enemyP.x * 10.0) * 0.05);
    
    float enemyMask = 0.0;
    if (abs(enemyP.x) < 0.15 && enemyP.y < 0.1 && enemyP.y > -0.2) {
        enemyMask = 1.0;
    }
    // Mushroom body
    if (abs(enemyP.x) < 0.1 && enemyP.y > -0.15 && enemyP.y < 0.05) {
        enemyMask = 1.0;
    }
    float3 enemyCol = float3(0.6, 0.4, 0.2);  // Brown
    col = mix(col, enemyCol, enemyMask * ground);
    
    // Mario-style coin
    float2 coinP = pixelP - float2(-0.3, 0.3 + sin(t * 3.0) * 0.1);
    float coinDist = length(coinP);
    float coin = smoothstep(0.08, 0.06, coinDist);
    float3 coinCol = float3(1.0, 0.85, 0.2);  // Gold
    
    // Coin shine
    float shine = step(0.0, coinP.x) * step(coinP.x, 0.03) * step(coinP.y + 0.02, coinP.y + 0.05);
    coinCol = mix(coinCol, float3(1.0), shine);
    
    col = mix(col, coinCol, coin);
    
    // Bass boost - things get bigger/more intense
    float bassScale = 1.0 + u.bass * 0.3;
    col *= bassScale;
    
    // Treble - sparkle effect
    float sparkle = custom_random(pixelUV + floor(t * 10.0) * 0.1);
    sparkle = step(0.97, sparkle) * u.treble;
    col += float3(1.0, 1.0, 0.8) * sparkle;
    
    // Scanline effect (CRT)
    float scanline = sin(uv.y * pixelSize * 3.14159) * 0.5 + 0.5;
    scanline = mix(0.85, 1.0, scanline);
    col *= scanline;
    
    // Slight color separation (chromatic aberration for retro feel)
    float2 caOffset = float2(0.002, 0.0);
    
    // Dithering pattern
    float dither = step(0.5, fract(pixelUV.x * pixelSize * 0.5 + pixelUV.y * pixelSize * 0.5));
    col = mix(col * 0.95, col, dither);
    
    return float4(col, 1.0);
}
