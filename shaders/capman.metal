// CapMan - Classic 2D Pac-Man Style Shader
#include "ShaderInterop.h"

using namespace metal;

// Classic Pac-Man maze (21x21 grid - original arcade size)
float maze[21][21] = {
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1},
    {1,0,1,1,0,1,1,1,1,0,1,0,1,1,1,1,0,1,1,0,1},
    {1,0,1,1,0,1,1,1,1,0,1,0,1,1,1,1,0,1,1,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,1,1,0,1,0,1,1,1,1,1,1,1,0,1,0,1,1,0,1},
    {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1},
    {1,1,1,1,0,1,1,1,1,0,1,0,1,1,1,1,0,1,1,1,1},
    {1,1,1,1,0,1,2,2,2,2,2,2,2,2,2,1,0,1,1,1,1},
    {1,2,2,1,0,1,2,1,1,1,2,1,1,1,2,1,0,1,2,2,1},
    {1,1,1,1,0,1,2,1,2,2,2,2,2,1,2,1,0,1,1,1,1},
    {1,1,1,1,0,1,2,1,1,1,1,1,1,1,2,1,0,1,1,1,1},
    {1,2,2,2,0,2,2,1,1,1,2,1,1,1,2,2,0,2,2,2,1},
    {1,1,1,1,0,1,2,1,1,1,2,1,1,1,2,1,0,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1},
    {1,0,1,1,0,1,1,1,1,0,1,0,1,1,1,1,0,1,1,0,1},
    {1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1},
    {1,1,0,1,0,1,0,1,1,1,1,1,1,1,0,1,0,1,0,1,1},
    {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

// Ghost colors (classic Pac-Man ghosts)
float3 ghostColors[4] = {
    float3(1.0, 0.0, 0.0),
    float3(0.0, 1.0, 1.0),
    float3(1.0, 0.5, 0.7),
    float3(1.0, 0.6, 0.0)
};

float isWall(float2 pos) {
    int x = int((pos.x + 10.5));
    int y = int((pos.y + 10.5));
    if (x < 0 || x > 20 || y < 0 || y > 19) return 1.0;
    return float(maze[y][x] == 1);
}

float hasPellet(float2 pos) {
    int x = int((pos.x + 10.5));
    int y = int((pos.y + 10.5));
    if (x < 0 || x > 20 || y < 0 || y > 19) return 0.0;
    return float(maze[y][x] == 0) * 0.5;
}

float hasPowerPellet(float2 pos) {
    int x = int((pos.x + 10.5));
    int y = int((pos.y + 10.5));
    if (x < 0 || x > 20 || y < 0 || y > 19) return 0.0;
    return float(maze[y][x] == 2) * 0.8;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    
    float2 mazeUV = (uv - 0.5) * float2(1.8, 1.4) + 0.5;
    float2 mazePos = (mazeUV - 0.5) * 21.0;
    
    mazeUV = clamp(mazeUV, 0.0, 1.0);
    mazePos = clamp(mazePos, -10.5, 10.5);
    
    float2 gridPos = floor(mazePos + 10.5);
    float2 gridFrac = fract(mazePos + 10.5);
    
    float wall = isWall(mazePos);
    float pellet = hasPellet(mazePos);
    float powerPellet = hasPowerPellet(mazePos);
    
    float3 color = float3(0.02, 0.02, 0.05);
    
    if (wall > 0.5) {
        float3 wallColor = float3(0.1, 0.2, 0.8);
        float border = smoothstep(0.0, 0.1, gridFrac.x) * smoothstep(1.0, 0.9, gridFrac.x);
        border *= smoothstep(0.0, 0.1, gridFrac.y) * smoothstep(1.0, 0.9, gridFrac.y);
        color = mix(wallColor * 0.5, wallColor, border);
    }
    
    if (pellet > 0.1) {
        float2 pelletCenter = gridPos + 0.5 - 10.5;
        float pelletDist = length(mazePos - pelletCenter);
        float pelletAnim = sin(uniforms.time * 3.0 + gridPos.x * 0.5 + gridPos.y * 0.3) * 0.15 + 0.85;
        
        if (pelletDist < 0.15 * pelletAnim) {
            color = float3(1.0, 0.85, 0.4);
        }
    }
    
    if (powerPellet > 0.1) {
        float2 ppCenter = gridPos + 0.5 - 10.5;
        float ppDist = length(mazePos - ppCenter);
        float flash = sin(uniforms.time * 5.0) * 0.5 + 0.5;
        
        if (ppDist < 0.25 * (0.7 + flash * 0.3)) {
            color = float3(1.0, 0.9, 0.6) * (0.8 + flash * 0.4);
        }
    }
    
    float2 pacmanPos = float2(
        sin(uniforms.time * 0.8) * 4.0,
        cos(uniforms.time * 0.6) * 3.0
    );
    
    float mouthAngle = 0.3 + 0.2 * sin(uniforms.time * 8.0);
    float rotAngle = uniforms.time * 0.8;
    float2 rotatedPos = float2(
        (mazePos.x - pacmanPos.x) * cos(-rotAngle) - (mazePos.y - pacmanPos.y) * sin(-rotAngle),
        (mazePos.x - pacmanPos.x) * sin(-rotAngle) + (mazePos.y - pacmanPos.y) * cos(-rotAngle)
    );
    
    float pacmanSize = 0.35;
    float pacmanBody = length(rotatedPos / float2(pacmanSize, pacmanSize * 1.2));
    
    float mouthWedge = abs(atan2(rotatedPos.y, rotatedPos.x));
    if (pacmanBody < 1.0 && mouthWedge > mouthAngle) {
        pacmanBody = 1.0;
    }
    
    if (pacmanBody < 1.0) {
        color = float3(1.0, 0.9, 0.0);
    }
    
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        
        float ghostAngle = uniforms.time * 0.4 + fi * 1.57;
        float ghostRadius = 3.0 + sin(uniforms.time * 0.5) * 1.5;
        
        float2 ghostPos = pacmanPos + float2(
            cos(ghostAngle) * ghostRadius,
            sin(ghostAngle) * ghostRadius
        );
        
        float ghostDist = length(mazePos - ghostPos);
        
        if (ghostDist < 0.38) {
            float2 localPos = (mazePos - ghostPos) / 0.35;
            float bodyDist = length(localPos);
            
            float wave = sin(localPos.x * 6.0 + uniforms.time * 8.0 + fi) * 0.1;
            if (localPos.y < -0.3) {
                bodyDist = length(float2(localPos.x, localPos.y - wave));
            }
            
            if (bodyDist < 1.1) {
                color = ghostColors[i];
                
                float eyeDist1 = length((mazePos - ghostPos) - float2(0.12, 0.12));
                float eyeDist2 = length((mazePos - ghostPos) - float2(-0.12, 0.12));
                
                if (eyeDist1 < 0.12 || eyeDist2 < 0.12) {
                    color = float3(1.0);
                    
                    if (eyeDist1 < 0.06 || eyeDist2 < 0.06) {
                        color = float3(0.0, 0.0, 0.8);
                    }
                }
            }
        }
    }
    
    float scanline = sin(uv.y * uniforms.resolution.y * 2.0) * 0.5 + 0.5;
    color *= 0.95 + scanline * 0.05;
    
    float vignette = 1.0 - length(uv - 0.5) * 0.8;
    color *= vignette;
    
    color += float3(0.02, 0.02, 0.05);
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
