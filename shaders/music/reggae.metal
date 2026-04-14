// Reggae 3D - Tropical Jamaican Flag
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    // Cloth physics for flag - multiple wave frequencies
    float wave1 = sin(uv.x * 3.0 - t * 2.5) * 0.12 * (uv.x + 0.15);
    float wave2 = sin(uv.x * 7.0 - t * 4.0 + 1.5) * 0.04 * (uv.x + 0.15);
    float wave3 = sin(uv.x * 15.0 - t * 6.0 + 3.0) * 0.015 * (uv.x + 0.15);
    float waveY = sin(uv.y * 4.0 - t * 1.5) * 0.03;
    float drape = pow(uv.x, 1.5) * 0.15;
    
    float2 wuv = uv + float2(0.0, wave1 + wave2 + wave3 + waveY - drape);
    
    // Sky gradient (tropical)
    float3 skyTop = float3(0.2, 0.5, 0.9);
    float3 skyBottom = float3(0.6, 0.8, 1.0);
    float3 color = mix(skyBottom, skyTop, uv.y * 0.8 + 0.1);
    
    // Sun with glow
    float2 sunPos = float2(0.75, 0.65);
    float sunDist = length(p - sunPos);
    float sun = smoothstep(0.25, 0.22, sunDist);
    float sunGlow = 0.15 / (1.0 + sunDist * 2.0);
    color = mix(color, float3(1.0, 0.95, 0.6), sun);
    color += float3(1.0, 0.8, 0.3) * sunGlow * 0.5;
    
    // Distant clouds
    float cloudNoise = snoise(float2(p.x * 2.0 + t * 0.05, p.y * 1.5 + 0.5));
    cloudNoise = smoothstep(0.3, 0.7, cloudNoise);
    float cloudMask = smoothstep(0.3, 0.8, uv.y);
    color = mix(color, float3(1.0, 1.0, 1.0), cloudNoise * cloudMask * 0.4);
    
    // Palm trees silhouette (left side)
    float2 pp = p - float2(-1.2, -0.9);
    float trunkWidth = 0.04 * (1.0 - smoothstep(0.0, 2.0, pp.y) * 0.7);
    float trunk = smoothstep(trunkWidth, trunkWidth * 0.5, abs(pp.x)) * 
                  step(0.0, pp.y) * step(pp.y, 2.2);
    float leaves = 0.0;
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float leafAngle = fi * 0.9 - 1.5 + sin(t * 0.3 + fi) * 0.1;
        float2 leafDir = float2(cos(leafAngle), sin(leafAngle));
        float2 leafP = pp - float2(0.0, 1.8 + fi * 0.08);
        float leafProj = dot(leafP, leafDir);
        if(leafProj > 0.0 && leafProj < 1.2) {
            float2 leafPerp = leafP - leafDir * leafProj;
            float leafWidth = (1.0 - leafProj / 1.2) * 0.15;
            leaves += smoothstep(leafWidth, leafWidth * 0.3, abs(leafPerp.x)) * 
                     step(leafProj, 1.2 - fi * 0.1);
        }
    }
    float palmSil = max(trunk, leaves);
    color = mix(color, float3(0.02, 0.04, 0.02), palmSil * smoothstep(2.5, 1.5, length(pp)));
    
    // Jamaican Flag - proper proportions and colors
    // Flag: diagonal cross (saltire) - green top-left to bottom-right, red top-right to bottom-left
    if(wuv.y > 0.15 && wuv.y < 0.85 && wuv.x > 0.05 && wuv.x < 0.95) {
        float2 flagUV = (wuv - float2(0.05, 0.15)) / float2(0.9, 0.7);
        
        // Black stripe in center (optional - Jamaica has gold but black is traditional)
        float centerWidth = 0.12;
        float centerDist = abs(flagUV.y - 0.5);
        
        // Diagonal crosses
        float diag1 = abs(flagUV.x - (1.0 - flagUV.y));
        float diag2 = abs(flagUV.x - flagUV.y);
        
        float stripeWidth = 0.15;
        
        // Green (top-left to bottom-right)
        float greenStripe = 1.0 - smoothstep(stripeWidth * 0.7, stripeWidth, diag1);
        // Red (top-right to bottom-left)  
        float redStripe = 1.0 - smoothstep(stripeWidth * 0.7, stripeWidth, diag2);
        
        // Yellow/gold triangle in middle
        float triangle = (1.0 - diag1) * (1.0 - diag2);
        triangle = smoothstep(0.3, 0.8, triangle);
        
        // Proper Jamaican colors
        float3 green = float3(0.0, 0.45, 0.15);  // Jamaican green
        float3 gold = float3(0.85, 0.65, 0.0);   // Jamaican gold
        float3 black = float3(0.08, 0.08, 0.08); // Black
        
        // Combine: green background, gold triangle, black cross borders
        float3 flagColor = green;
        flagColor = mix(flagColor, gold, triangle * 0.9);
        
        // Black diagonal bars
        float crossWidth = 0.08;
        float cross1 = 1.0 - smoothstep(crossWidth * 0.6, crossWidth, diag1);
        float cross2 = 1.0 - smoothstep(crossWidth * 0.6, crossWidth, diag2);
        
        // Keep center gold visible, extend black along diagonals
        float crossPattern = max(cross1, cross2);
        float crossMask = triangle > 0.5 ? crossPattern * 0.6 : crossPattern;
        flagColor = mix(flagColor, black, crossMask * 0.8);
        
        // Cloth shading based on wave displacement
        float shading = 1.0 + (wave1 + wave2) * 3.0;
        shading *= 0.85 + 0.15 * snoise(wuv * 50.0);
        
        // Fabric texture
        float fabricNoise = snoise(wuv * 150.0);
        float fabricDetail = snoise(wuv * 400.0);
        float fabric = 0.92 + 0.08 * fabricNoise + 0.03 * fabricDetail;
        
        // Thread lines
        float threads = sin(wuv.x * 300.0) * sin(wuv.y * 300.0);
        fabric += threads * 0.02;
        
        color = flagColor * shading * fabric;
        
        // Subtle shadows in folds
        float foldShadow = 1.0 - smoothstep(-0.02, 0.02, wave1 + wave2);
        color *= (1.0 - foldShadow * 0.2);
    }
    
    // Flagpole
    float2 polePos = float2(0.03, 0.1);
    float pole = smoothstep(0.015, 0.008, abs(p.x - polePos.x)) * 
                 step(polePos.y - 0.9, p.y) * step(p.y, polePos.y + 1.1);
    float poleShading = 0.7 + 0.3 * sin((p.y + 1.0) * 5.0);
    color = mix(color, float3(0.3, 0.28, 0.25) * poleShading, pole);
    
    // Pole cap (gold ball)
    float2 capP = p - float2(polePos.x, polePos.y + 1.1);
    float cap = smoothstep(0.035, 0.025, length(capP));
    color = mix(color, float3(0.85, 0.7, 0.2), cap);
    
    // Ground/sand
    if(p.y < -0.85) {
        float3 sand = float3(0.9, 0.85, 0.7);
        float sandTex = snoise(float2(p.x * 10.0, t * 0.1)) * 0.1;
        color = mix(sand, sand * 0.9, sandTex);
    }
    
    // Tropical birds
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float birdX = -0.3 + fi * 0.6 + sin(t * 0.8 + fi) * 0.3;
        float birdY = 0.5 + fi * 0.2 + sin(t * 1.2 + fi * 2.0) * 0.15;
        float2 birdP = p - float2(birdX, birdY);
        float wing = abs(birdP.x) < 0.08 && abs(birdP.y) < 0.015 ? 1.0 : 0.0;
        wing *= sin(t * 8.0 + fi * 3.0) * 0.5 + 0.5;
        color = mix(color, float3(0.1, 0.1, 0.1), wing * 0.8);
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}