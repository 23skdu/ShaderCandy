// CapMan - Pacman-inspired shader (Metal port)

#include "ShaderInterop.h"

float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.453);
}

float2 pacman(float2 uv, float t) {
    // Pacman mouth animation
    float mouth = 0.3 + 0.2 * sin(t * 3.0);
    float angle = atan2(uv.y, uv.x);
    
    // Create pacman shape - wedge open to the right
    float pacman_mask = step(length(uv), 0.3);
    pacman_mask *= step(mouth, abs(angle));
    
    return float2(pacman_mask, mouth);
}

float2 ghost(float2 uv, float3 color, float t) {
    // Ghost body shape
    float body = 0.0;
    
    // Main body (top circle)
    body = step(length(uv - float2(0.0, 0.0)), 0.25);
    // Cut off bottom
    body *= step(-0.1, uv.y);
    // Add rectangular bottom
    body = max(body, step(abs(uv.x), 0.25) * step(uv.y, 0.0) * step(-0.25, uv.y));
    
    // Ghost bottom bumps (waves)
    float wave = 0.05 * sin(uv.x * 20.0 + t * 5.0);
    body *= step(-0.25 + wave, uv.y);
    
    // Eyes
    float2 leftEye = float2(-0.08, 0.05);
    float2 rightEye = float2(0.08, 0.05);
    float eyes = step(length(uv - leftEye), 0.05) + step(length(uv - rightEye), 0.05);
    float pupils = step(length(uv - leftEye - float2(0.02, 0.0)), 0.02) + 
                    step(length(uv - rightEye - float2(0.02, 0.0)), 0.02);
    
    return float2(body, eyes - pupils);
}

float pellet(float2 uv, float t) {
    float isPowerPellet = step(0.9, random(floor(uv * 10.0))); // Random power pellets
    float radius = mix(0.02, 0.06, isPowerPellet);
    if (isPowerPellet > 0.5) {
        radius *= 0.8 + 0.2 * sin(t * 10.0); // Pulse power pellets
    }
    return step(length(uv), radius);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 coord = uv * 2.0 - 1.0;
    coord.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float3 color = float3(0.0);
    float gameTime = uniforms.gameTime;
    
    // Game grid
    float gridSize = 0.2;
    float2 grid = floor(coord / gridSize) * gridSize + gridSize * 0.5;
    
    // Draw pellets
    float pelletMask = pellet(coord - grid, gameTime);
    color += float3(1.0, 1.0, 0.2) * pelletMask;
    
    // Draw player (Pacman)
    // Add movement if playerPos is animated
    float2 pacmanResult = pacman(coord - uniforms.playerPos, gameTime);
    color = mix(color, float3(1.0, 1.0, 0.0), pacmanResult.x);
    
    // Draw ghosts
    float3 ghostColors[4];
    ghostColors[0] = float3(1.0, 0.0, 0.0); // Blinky
    ghostColors[1] = float3(0.0, 1.0, 1.0); // Inky
    ghostColors[2] = float3(1.0, 0.647, 0.0); // Clyde
    ghostColors[3] = float3(1.0, 0.7, 0.8); // Pinky
    
    for (int i = 0; i < 4; i++) {
        float2 ghostResult = ghost(coord - uniforms.ghostPos[i], ghostColors[i], gameTime);
        color = mix(color, ghostColors[i], ghostResult.x);
        color = mix(color, float3(1.0), clamp(ghostResult.y, 0.0, 1.0)); // White of eyes
    }
    
    // Maze walls
    float wallMask = 0.0;
    float2 wallCoord = abs(fract(coord / gridSize + 0.5) - 0.5) / (gridSize * 0.5);
    wallMask = max(wallCoord.x, wallCoord.y);
    wallMask = smoothstep(0.48, 0.5, wallMask);
    
    // Dark blue walls
    color = mix(color, float3(0.0, 0.0, 0.4), wallMask * 0.5);
    
    // Score display
    if (coord.y > 0.9) {
        float scoreBar = step(coord.y, 0.95);
        float scoreProgress = fract(uniforms.score * 0.001);
        float scoreMask = step(coord.x, scoreProgress * 2.0 - 1.0);
        color = mix(color, float3(1.0, 1.0, 0.0), scoreMask * scoreBar);
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
