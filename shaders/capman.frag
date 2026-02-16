#version 450 core

#include "../base/common.glsl"

// CapMan - Pacman-inspired shader

// Game state
uniform float gameTime;
uniform vec2 playerPos;
uniform vec2 ghostPos[4];
uniform float score;
uniform float lives;
uniform float level;

// Utility functions
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.453);
}

vec2 pacman(vec2 uv, float t) {
    // Pacman mouth animation
    float mouth = 0.3 + 0.2 * sin(t * 3.0);
    float angle = atan(uv.y, uv.x);
    
    // Create pacman shape
    float pacman = step(length(uv), 0.3);
    pacman *= step(abs(angle), mouth);
    
    return vec2(pacman, mouth);
}

vec2 ghost(vec2 uv, vec3 color, float t) {
    // Ghost body shape
    float body = 0.0;
    
    // Main body (circle)
    body = step(length(uv - vec2(0.0, -0.1)), 0.25);
    
    // Ghost bottom bumps
    vec2 bumps[3];
    bumps[0] = vec2(-0.15, -0.25);
    bumps[1] = vec2(0.0, -0.25);
    bumps[2] = vec2(0.15, -0.25);
    
    for (int i = 0; i < 3; i++) {
        body *= 1.0 - step(length(uv - bumps[i]), 0.08);
    }
    
    // Eyes
    vec2 leftEye = vec2(-0.08, 0.05);
    vec2 rightEye = vec2(0.08, 0.05);
    float eyes = step(length(uv - leftEye), 0.05) + step(length(uv - rightEye), 0.05);
    
    return vec2(body, eyes);
}

float pellet(vec2 uv, float t) {
    // Power pellet (larger) or regular pellet
    float isPowerPellet = step(0.5, random(uv + t));
    float radius = mix(0.02, 0.05, isPowerPellet);
    
    return step(length(uv), radius);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 coord = uv * 2.0 - 1.0;
    coord.x *= resolution.x / resolution.y;
    
    vec3 color = vec3(0.0);
    float alpha = 1.0;
    
    // Game grid
    float gridSize = 0.2;
    vec2 grid = floor(coord / gridSize) * gridSize + gridSize * 0.5;
    
    // Draw pellets
    float pelletMask = pellet(coord - grid, gameTime);
    color += vec3(1.0, 1.0, 0.2) * pelletMask;
    
    // Draw player (Pacman)
    vec2 pacmanResult = pacman(coord - playerPos, gameTime);
    color += vec3(1.0, 1.0, 0.0) * pacmanResult.x;
    
    // Draw ghosts
    vec3 ghostColors[4];
    ghostColors[0] = vec3(1.0, 0.0, 0.0); // Blinky (red)
    ghostColors[1] = vec3(0.0, 1.0, 1.0); // Inky (cyan)
    ghostColors[2] = vec3(1.0, 0.647, 0.0); // Clyde (orange)
    ghostColors[3] = vec3(0.5, 0.0, 1.0); // Pinky (pink)
    
    for (int i = 0; i < 4; i++) {
        vec2 ghostResult = ghost(coord - ghostPos[i], ghostColors[i], gameTime);
        color += ghostColors[i] * ghostResult.x;
    }
    
    // Maze walls (simple grid pattern)
    float wallMask = 0.0;
    vec2 wallCoord = abs(fract(coord / gridSize + 0.5) - 0.5) / (gridSize * 0.5);
    wallMask = max(wallCoord.x, wallCoord.y);
    wallMask = smoothstep(0.05, 0.06, wallMask);
    
    // Add walls with dark blue color
    color = mix(color, vec3(0.0, 0.0, 0.3), wallMask);
    
    // Score display (simple bar at bottom)
    if (coord.y > 0.9) {
        float scoreBar = step(coord.y, 0.95);
        float scoreProgress = fract(score * 0.01);
        float scoreMask = step(coord.x, scoreProgress * 2.0 - 1.0);
        
        color = mix(vec3(0.0, 0.0, 0.1), vec3(1.0, 1.0, 0.0), scoreMask * scoreBar);
    }
    
    // Lives display (simple icons at top)
    if (coord.y < -0.9) {
        float livesBar = step(coord.y, -0.95);
        float pacmanIcon = pacman(coord * 2.0, gameTime).x;
        color += vec3(1.0, 1.0, 0.0) * pacmanIcon * livesBar;
    }
    
    return vec4(color, alpha);
}