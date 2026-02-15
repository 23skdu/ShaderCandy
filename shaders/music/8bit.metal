#include "ShaderInterop.h"


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

// Draw a rectangle
float rect(float2 p, float2 pos, float2 size) {
    float2 d = abs(p - pos) - size * 0.5;
    return step(max(d.x, d.y), 0.0);
}

// Draw a circle
float circle(float2 p, float2 pos, float r) {
    return step(length(p - pos), r);
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
    
    // Sky - classic blue with gradient
    float3 skyCol = mix(float3(0.3, 0.6, 1.0), float3(0.5, 0.8, 1.0), uv.y);
    float3 col = skyCol;
    
    // Scrolling clouds with faces (Mario-style)
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 cloudPos = pixelP;
        cloudPos.x += t * 0.2 + fi * 1.5;
        cloudPos.x = mod(cloudPos.x + 2.0, 4.0) - 2.0;
        cloudPos.y += 0.3 + fi * 0.1;
        
        float cloud = 0.0;
        // Cloud puffs
        cloud += circle(pixelP, cloudPos + float2(0.0, 0.0), 0.15);
        cloud += circle(pixelP, cloudPos + float2(-0.12, 0.0), 0.1);
        cloud += circle(pixelP, cloudPos + float2(0.12, 0.0), 0.1);
        cloud += circle(pixelP, cloudPos + float2(-0.06, 0.08), 0.08);
        cloud += circle(pixelP, cloudPos + float2(0.06, 0.08), 0.08);
        cloud = step(0.5, cloud);
        
        // Cloud face (eyes)
        float eyeL = circle(pixelP, cloudPos + float2(-0.05, 0.0), 0.02);
        float eyeR = circle(pixelP, cloudPos + float2(0.05, 0.0), 0.02);
        
        col = mix(col, float3(1.0), cloud);
        col = mix(col, float3(0.0), (eyeL + eyeR) * cloud);
    }
    
    // Ground hills (green layers for parallax)
    float ground1 = smoothstep(-0.3, -0.25, pixelP.y + 0.05 * sin(pixelP.x * 2.0));
    float3 groundCol1 = float3(0.15, 0.6, 0.15);
    col = mix(col, groundCol1, ground1 * step(pixelP.y, -0.2));
    
    float ground2 = smoothstep(-0.4, -0.35, pixelP.y);
    float3 groundCol2 = float3(0.2, 0.7, 0.2);
    float groundDetail = step(0.5, fract(pixelP.x * 8.0 + pixelP.y * 4.0));
    groundCol2 = mix(groundCol2, float3(0.15, 0.5, 0.15), groundDetail * 0.3);
    col = mix(col, groundCol2, ground2);
    
    // Ground line
    float groundLine = smoothstep(-0.38, -0.4, pixelP.y) * smoothstep(-0.42, -0.4, pixelP.y);
    col = mix(col, float3(0.6, 0.3, 0.1), groundLine);
    
    // Brick platforms
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float2 platPos = pixelP;
        platPos.x = mod(platPos.x + t * 0.3 + fi * 0.8, 3.0) - 1.5;
        platPos.y -= 0.1 + fi * 0.15;
        
        float platform = rect(pixelP, platPos + float2(0.0, 0.0), float2(0.4, 0.08));
        float3 brickCol = float3(0.7, 0.3, 0.1);
        // Brick pattern
        float brickPattern = step(0.5, fract((pixelP.x - platPos.x) * 10.0));
        brickPattern *= step(0.5, fract((pixelP.y - platPos.y) * 20.0 + brickPattern * 0.5));
        brickCol = mix(brickCol, float3(0.5, 0.2, 0.05), brickPattern * 0.3);
        
        col = mix(col, brickCol, platform * step(pixelP.y, platPos.y + 0.04));
    }
    
    // Question blocks (Mario style)
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 blockP = pixelP;
        blockP.x += fi * 0.6 - 0.6;
        blockP.y += 0.2 + sin(t * 2.0 + fi) * 0.03;
        
        float block = rect(pixelP, blockP, float2(0.12, 0.12));
        float3 blockCol = float3(0.9, 0.7, 0.3); // Gold block
        
        // Question mark
        float2 localP = (pixelP - blockP) * 8.0;
        float qMark = 0.0;
        qMark += rect(pixelP, blockP + float2(0.0, 0.02), float2(0.04, 0.02)); // Top
        qMark += rect(pixelP, blockP + float2(0.02, 0.0), float2(0.02, 0.04)); // Right side
        qMark += rect(pixelP, blockP + float2(0.0, -0.02), float2(0.03, 0.02)); // Bottom curve
        qMark += rect(pixelP, blockP + float2(0.0, -0.05), float2(0.02, 0.02)); // Dot
        
        blockCol = mix(blockCol, float3(0.8, 0.2, 0.1), qMark);
        col = mix(col, blockCol, block);
    }
    
    // Pipes (green tubes)
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float2 pipeP = pixelP;
        pipeP.x = mod(pipeP.x + fi * 1.5 - t * 0.1, 4.0) - 2.0;
        
        float pipeBody = rect(pixelP, pipeP + float2(0.0, -0.35), float2(0.2, 0.3));
        float pipeTop = rect(pixelP, pipeP + float2(0.0, -0.15), float2(0.26, 0.08));
        float pipe = max(pipeBody, pipeTop);
        
        float3 pipeCol = float3(0.1, 0.6, 0.2);
        // Pipe gradient
        float pipeGrad = step(pixelP.x, pipeP.x);
        pipeCol = mix(pipeCol, float3(0.15, 0.7, 0.25), pipeGrad * 0.3);
        
        col = mix(col, pipeCol, pipe * ground2);
    }
    
    // Goomba-like enemies
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float2 enemyP = pixelP;
        enemyP.x = mod(enemyP.x + t * 0.8 + fi * 0.5 + 0.5, 3.0) - 1.5;
        enemyP.y = -0.35 + abs(sin(t * 5.0 + fi * 2.0)) * 0.08;
        
        // Feet
        float footL = circle(pixelP, enemyP + float2(-0.06, -0.08), 0.04);
        float footR = circle(pixelP, enemyP + float2(0.06, -0.08), 0.04);
        // Body
        float body = circle(pixelP, enemyP + float2(0.0, 0.0), 0.1);
        // Eyebrows
        float brow = rect(pixelP, enemyP + float2(0.0, 0.04), float2(0.12, 0.02));
        
        float enemy = max(max(footL, footR), max(body, brow));
        float3 enemyCol = float3(0.6, 0.4, 0.2);
        
        col = mix(col, enemyCol, enemy * ground2);
    }
    
    // Koopa-style turtle enemies
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float2 turtleP = pixelP;
        turtleP.x = mod(turtleP.x - t * 0.5 + fi * 2.0, 4.0) - 2.0;
        turtleP.y = -0.35;
        
        // Shell
        float shell = circle(pixelP, turtleP + float2(0.0, 0.02), 0.08);
        // Head
        float head = circle(pixelP, turtleP + float2(0.1, 0.0), 0.05);
        // Feet
        float foot1 = circle(pixelP, turtleP + float2(-0.05, -0.08), 0.03);
        float foot2 = circle(pixelP, turtleP + float2(0.05, -0.08), 0.03);
        
        float turtle = max(max(shell, head), max(foot1, foot2));
        float3 shellCol = float3(0.2, 0.5, 0.2); // Green shell
        float3 skinCol = float3(0.8, 0.7, 0.4);  // Yellow skin
        
        col = mix(col, shellCol, shell * ground2);
        col = mix(col, skinCol, (head + foot1 + foot2) * ground2);
    }
    
    // Flying enemies (winged)
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float2 flyP = pixelP;
        flyP.x = mod(flyP.x + t * 0.6 + fi, 3.0) - 1.5;
        flyP.y = 0.1 + sin(t * 3.0 + fi) * 0.15;
        
        // Body
        float body = circle(pixelP, flyP, 0.06);
        // Wings (flapping)
        float wingY = sin(t * 15.0 + fi) * 0.05;
        float wingL = rect(pixelP, flyP + float2(-0.08, wingY), float2(0.06, 0.02));
        float wingR = rect(pixelP, flyP + float2(0.08, wingY), float2(0.06, 0.02));
        
        float flyer = max(body, max(wingL, wingR));
        float3 flyerCol = float3(0.7, 0.2, 0.2); // Red flying enemy
        
        col = mix(col, flyerCol, flyer);
    }
    
    // Mario-style coins
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 coinP = pixelP - float2(-0.8 + fi * 0.4, 0.0);
        coinP.y += sin(t * 3.0 + fi * 1.5) * 0.15;
        
        float coinDist = length(coinP);
        float coin = smoothstep(0.06, 0.05, coinDist);
        float3 coinCol = float3(1.0, 0.85, 0.2); // Gold
        
        // Coin shine
        float shine = step(0.0, coinP.x) * step(coinP.x, 0.02) * step(-0.02, coinP.y) * step(coinP.y, 0.02);
        coinCol = mix(coinCol, float3(1.0), shine);
        
        col = mix(col, coinCol, coin);
    }
    
    // Power-up mushrooms
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float2 shroomP = pixelP;
        shroomP.x = mod(shroomP.x + t * 0.2 + fi * 1.5, 3.0) - 1.5;
        shroomP.y = -0.3 + abs(sin(t * 4.0 + fi)) * 0.1;
        
        // Cap
        float cap = circle(pixelP, shroomP + float2(0.0, 0.05), 0.08);
        // Stem
        float stem = rect(pixelP, shroomP + float2(0.0, -0.04), float2(0.06, 0.08));
        // Spots on cap
        float spot1 = circle(pixelP, shroomP + float2(-0.04, 0.06), 0.02);
        float spot2 = circle(pixelP, shroomP + float2(0.04, 0.06), 0.02);
        float spot3 = circle(pixelP, shroomP + float2(0.0, 0.09), 0.015);
        
        float shroom = max(cap, stem);
        float3 shroomCol = float3(0.9, 0.2, 0.1); // Red cap
        float3 spotCol = float3(1.0, 1.0, 1.0);   // White spots
        float3 stemCol = float3(0.9, 0.8, 0.7);   // Beige stem
        
        col = mix(col, shroomCol, cap * ground2);
        col = mix(col, spotCol, (spot1 + spot2 + spot3) * cap * ground2);
        col = mix(col, stemCol, stem * ground2);
    }
    
    // Star power-ups
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float2 starP = pixelP;
        starP.x = mod(starP.x - t * 0.4 + fi * 2.0, 4.0) - 2.0;
        starP.y = 0.0 + sin(t * 4.0 + fi * 3.0) * 0.1;
        
        // Simple star shape using circles
        float star = 0.0;
        for(int j = 0; j < 5; j++) {
            float fj = float(j);
            float angle = fj * 6.28318 / 5.0 + t * 2.0;
            float2 offset = float2(cos(angle), sin(angle)) * 0.06;
            star += circle(pixelP, starP + offset, 0.03);
        }
        star = step(0.5, star);
        
        float3 starCol = float3(1.0, 0.9, 0.0); // Yellow star
        starCol += float3(0.2, 0.2, 0.0) * sin(t * 10.0 + fi); // Twinkle
        
        col = mix(col, starCol, star);
    }
    
    // Castle at the end
    float2 castleP = pixelP;
    castleP.x = mod(castleP.x + 1.5, 4.0) - 2.0;
    castleP.y += 0.35;
    
    // Main tower
    float tower = rect(pixelP, castleP + float2(0.0, 0.0), float2(0.3, 0.4));
    // Side towers
    float sideL = rect(pixelP, castleP + float2(-0.25, -0.1), float2(0.15, 0.25));
    float sideR = rect(pixelP, castleP + float2(0.25, -0.1), float2(0.15, 0.25));
    // Door
    float door = rect(pixelP, castleP + float2(0.0, -0.15), float2(0.1, 0.15));
    // Flag
    float pole = rect(pixelP, castleP + float2(0.0, 0.3), float2(0.01, 0.15));
    float flag = rect(pixelP, castleP + float2(0.06, 0.4), float2(0.08, 0.05));
    
    float castle = max(max(tower, max(sideL, sideR)), max(pole, flag));
    castle = max(castle, 1.0 - door); // Cut out door
    
    float3 castleCol = float3(0.4, 0.2, 0.1); // Brown bricks
    float3 doorCol = float3(0.2, 0.1, 0.05);  // Dark door
    float3 flagCol = float3(1.0, 0.0, 0.0);   // Red flag
    
    col = mix(col, castleCol, castle * ground2);
    col = mix(col, doorCol, door * ground2);
    col = mix(col, flagCol, flag * ground2);
    
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
