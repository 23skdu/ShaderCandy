// CapMan 3D - Raymarched Pacman Game Board
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

struct Ray {
    float3 origin;
    float3 direction;
};

// Classic Pac-Man maze pattern
float mazeSDF(float3 p) {
    float2 pos = p.xz * 2.0;
    float2 absPos = abs(pos);
    
    // Outer walls
    float wall = 1e10;
    
    // Create maze corridors
    float corridorWidth = 0.3;
    
    // Horizontal corridors
    for(int i = -2; i <= 2; i++) {
        float y = float(i) * 0.6;
        float hWall = abs(pos.y - y) - corridorWidth * 0.5;
        if(absPos.x < 1.8) wall = min(wall, max(hWall, absPos.x - 1.8));
    }
    
    // Vertical corridors
    for(int i = -1; i <= 1; i++) {
        float x = float(i) * 1.2;
        float vWall = abs(pos.x - x) - corridorWidth * 0.5;
        if(absPos.y < 1.5) wall = min(wall, max(vWall, absPos.y - 1.5));
    }
    
    // Corner pieces
    float corner = length(max(absPos - float2(1.5, 1.2), 0.0)) - 0.3;
    wall = min(wall, corner);
    
    // Wall height
    wall = max(wall, abs(p.y - 0.4) - 0.4);
    
    return wall;
}

// Pellet/dots
float pelletSDF(float3 p) {
    float2 pos = p.xz * 2.0;
    
    float pellet = 1e10;
    for(int x = -2; x <= 2; x++) {
        for(int y = -2; y <= 2; y++) {
            float2 pelletPos = float2(float(x) * 0.6, float(y) * 0.6);
            float2 gridPos = floor(pos / 0.6 + 0.5) * 0.6;
            
            // Skip positions near walls
            if(abs(gridPos.x) < 1.7 && abs(gridPos.y) < 1.4) {
                float d = length(pos - pelletPos) - 0.05;
                pellet = min(pellet, d);
            }
        }
    }
    
    // Height constraint for pellets
    pellet = max(pellet, abs(p.y - 0.1) - 0.05);
    
    return pellet;
}

// Power pellets (larger, in corners)
float powerPelletSDF(float3 p) {
    float2 pos = p.xz * 2.0;
    float2 corners[4] = {
        float2(-1.5, -1.2),
        float2(1.5, -1.2),
        float2(-1.5, 1.2),
        float2(1.5, 1.2)
    };
    
    float power = 1e10;
    for(int i = 0; i < 4; i++) {
        float d = length(pos - corners[i]) - 0.08;
        power = min(power, d);
    }
    
    power = max(power, abs(p.y - 0.1) - 0.08);
    return power;
}

float map(float3 p, float time, constant Uniforms &uniforms) {
    float d = 1e10;
    
    // Maze walls
    float maze = mazeSDF(p);
    d = min(d, maze);
    
    // Floor
    float floor = p.y + 0.1;
    d = min(d, floor);
    
    // Pellets
    float pellets = pelletSDF(p);
    d = min(d, pellets);
    
    // Power pellets
    float powerPellets = powerPelletSDF(p);
    d = min(d, powerPellets);
    
    // Pacman
    float3 pp = p - float3(uniforms.playerPos.x, 0.25, uniforms.playerPos.y);
    float mouth = 0.3 + 0.25 * sin(time * 15.0);
    float pdist = sdSphere(pp, 0.22);
    // Cut mouth wedge
    float angle = atan2(pp.z, pp.x);
    if (abs(angle) < mouth && pp.x > 0.0) pdist = max(pdist, length(pp.xz) * 0.5);
    
    d = min(d, pdist);
    
    // Ghosts with ghost shape
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float3 gp = p - float3(
            uniforms.ghostPos[i].x,
            0.25 + 0.05 * sin(time * 4.0 + fi),
            uniforms.ghostPos[i].y
        );
        
        // Ghost body (rounded top, flat bottom with wavy edges)
        float ghostBody = sdSphere(gp, 0.18);
        ghostBody = max(ghostBody, -(gp.y + 0.05)); // Flat bottom
        
        // Ghost "skirt"
        float skirt = length(gp.xz) - 0.18;
        skirt = max(skirt, gp.y + 0.15);
        skirt = max(skirt, -(gp.y + 0.05));
        // Wavy bottom
        skirt += sin(gp.x * 20.0 + time * 3.0 + fi) * 0.01;
        
        float gdist = min(ghostBody, skirt);
        d = min(d, gdist);
    }
    
    return d;
}

float3 getNormal(float3 p, float time, constant Uniforms &uniforms) {
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + e.xyy, time, uniforms) - map(p - e.xyy, time, uniforms),
        map(p + e.yxy, time, uniforms) - map(p - e.yxy, time, uniforms),
        map(p + e.yyx, time, uniforms) - map(p - e.yyx, time, uniforms)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float3 ro = float3(0.0, 3.5, -5.0);
    float3 rd = normalize(float3(uv, 1.5));
    
    // Camera follows action
    float ang = uniforms.time * 0.05;
    float camRadius = 5.0;
    ro.xz = float2(camRadius * sin(ang), -camRadius * cos(ang));
    rd = lookAt(ro, float3(uniforms.playerPos.x, 0, uniforms.playerPos.y)) * rd;

    float t = 0.0;
    float3 accumulatedColor = float3(0.0);
    float glow = 0.0;
    
    for (int i = 0; i < 80; i++) {
        float3 p = ro + rd * t;
        float d = map(p, uniforms.time, uniforms);
        
        // Glow effect for pellets
        float pelletDist = pelletSDF(p);
        glow += 0.005 / (1.0 + pelletDist * 5.0);
        
        if (d < 0.001 || t > 15.0) break;
        t += d;
    }
    
    float3 color = float3(0.0, 0.0, 0.05); // Dark arcade background
    
    if (t < 15.0) {
        float3 p = ro + rd * t;
        float3 n = getNormal(p, uniforms.time, uniforms);
        float3 light = normalize(float3(1.0, 3.0, -2.0));
        float diff = max(dot(n, light), 0.0);
        float spec = pow(max(dot(reflect(-light, n), -rd), 0.0), 32.0);
        
        // Determine what we hit
        float3 baseColor = float3(0.0);
        float emissive = 0.0;
        
        // Check if it's a wall
        if (mazeSDF(p) < 0.01) {
            baseColor = float3(0.1, 0.1, 0.8); // Classic blue walls
            // Wall edge highlighting
            float edge = 1.0 - abs(dot(n, float3(0, 1, 0)));
            baseColor += float3(0.2, 0.2, 0.4) * edge;
        }
        // Check if it's the floor
        else if (p.y < -0.05) {
            baseColor = float3(0.0, 0.0, 0.0); // Black floor
            // Grid pattern
            float2 grid = fract(p.xz * 4.0);
            float gridLine = step(0.95, max(grid.x, grid.y));
            baseColor += float3(0.05, 0.05, 0.1) * gridLine;
        }
        // Check if it's a pellet
        else if (pelletSDF(p) < 0.01) {
            baseColor = float3(1.0, 0.8, 0.4); // Yellow pellets
            emissive = 0.5;
        }
        // Check if it's a power pellet
        else if (powerPelletSDF(p) < 0.01) {
            float flash = 0.5 + 0.5 * sin(uniforms.time * 10.0);
            baseColor = float3(1.0, 0.8, 0.4) * (0.5 + flash * 0.5);
            emissive = 0.8;
        }
        // Check if it's Pacman
        else {
            float3 pp = p - float3(uniforms.playerPos.x, 0.25, uniforms.playerPos.y);
            if (length(pp) < 0.25) {
                baseColor = float3(1.0, 1.0, 0.0); // Yellow Pacman
            } else {
                // Ghost colors
                for (int i = 0; i < 4; i++) {
                    float3 gp = p - float3(
                        uniforms.ghostPos[i].x,
                        0.25 + 0.05 * sin(uniforms.time * 4.0 + float(i)),
                        uniforms.ghostPos[i].y
                    );
                    if (length(gp) < 0.2) {
                        float3 gCol[4] = {
                            float3(1, 0.2, 0.2),    // Blinky (Red)
                            float3(0.2, 1, 1),      // Inky (Cyan)
                            float3(1, 0.6, 0.5),    // Pinky (Pink)
                            float3(1, 0.6, 0.2)     // Clyde (Orange)
                        };
                        baseColor = gCol[i];
                        
                        // Ghost eyes
                        if (gp.y > 0.15 && abs(gp.x) > 0.05) {
                            baseColor = float3(1.0, 1.0, 1.0); // White eye
                            if (length(gp - float3(gp.x > 0 ? 0.08 : -0.08, 0.18, 0.1)) < 0.03) {
                                baseColor = float3(0.0, 0.0, 0.5); // Blue pupil
                            }
                        }
                    }
                }
            }
        }
        
        color = baseColor * (diff + 0.3) + float3(1.0) * spec * 0.5;
        color += baseColor * emissive;
    }
    
    // Add pellet glow
    color += float3(1.0, 0.9, 0.5) * glow * 2.0;
    
    // Vignette for arcade feel
    float vignette = 1.0 - length(in.texCoord - 0.5) * 0.8;
    color *= vignette;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
