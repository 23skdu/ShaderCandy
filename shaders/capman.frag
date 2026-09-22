#include "base/common.glsl"

// CapMan - Authentic Retro Arcade Pac-Man Experience
// Complete with classic 28x31 neon-bordered maze, pellets, power energizers,
// animated chomping Pac-Man, 4 authentic ghosts with ruffled skirts & directional eyes,
// scared ghost mode, arcade HUD, cherry fruit bonus, extra lives, and CRT arcade framing.

// -----------------------------------------------------------------------------
// 1. Classic Pac-Man 28x31 Maze Bitmask (Symmetrical left 14 columns)
// -----------------------------------------------------------------------------
const int maze[31] = int[31](
    0x3FFF, 0x2001, 0x2F7D, 0x2F7D, 0x2F7D, 0x2000, 0x2F6F, 0x2F6F,
    0x2061, 0x3F7D, 0x017D, 0x0160, 0x016F, 0x3F68, 0x0008, 0x3F68,
    0x016F, 0x0160, 0x016F, 0x3F6F, 0x2001, 0x2F7D, 0x2F7D, 0x2300,
    0x3B6F, 0x3B6F, 0x2061, 0x2FFD, 0x2FFD, 0x2001, 0x3FFF
);

bool isWall(int x, int y) {
    if (y < 0 || y >= 31) return true;
    if (x < 0 || x >= 28) {
        if (y == 14) return false; // Side escape tunnel
        return true;
    }
    int c = (x < 14) ? x : (27 - x);
    return ((maze[y] >> (13 - c)) & 1) != 0;
}

bool isPelletTile(int x, int y) {
    if (isWall(x, y)) return false;
    if (y == 14) return false; // Side tunnel
    if ((y >= 9 && y <= 19) && (x <= 5 || x >= 22)) return false;
    if (x >= 10 && x <= 17 && y >= 11 && y <= 17) return false; // Ghost house
    if (x >= 11 && x <= 16 && y == 11) return false;
    return true;
}

bool isPowerPellet(int x, int y) {
    return (x == 1 && y == 3) || (x == 26 && y == 3) ||
           (x == 1 && y == 23) || (x == 26 && y == 23);
}

// -----------------------------------------------------------------------------
// 2. Continuous Waypoint Corridor Circuit
// -----------------------------------------------------------------------------
const vec2 corners[25] = vec2[25](
    vec2(1.5, 1.5), vec2(12.5, 1.5), vec2(12.5, 5.5), vec2(15.5, 5.5), vec2(15.5, 1.5),
    vec2(26.5, 1.5), vec2(26.5, 5.5), vec2(21.5, 5.5), vec2(21.5, 20.5), vec2(26.5, 20.5),
    vec2(26.5, 23.5), vec2(24.5, 23.5), vec2(24.5, 26.5), vec2(21.5, 26.5), vec2(21.5, 23.5),
    vec2(6.5, 23.5), vec2(6.5, 26.5), vec2(3.5, 26.5), vec2(3.5, 23.5), vec2(1.5, 23.5),
    vec2(1.5, 20.5), vec2(6.5, 20.5), vec2(6.5, 5.5), vec2(1.5, 5.5), vec2(1.5, 1.5)
);

const float cumDist[25] = float[25](
    0.0, 11.0, 15.0, 18.0, 22.0, 33.0, 37.0, 42.0, 57.0, 62.0,
    65.0, 67.0, 70.0, 73.0, 76.0, 91.0, 94.0, 97.0, 100.0, 102.0,
    105.0, 110.0, 125.0, 130.0, 134.0
);

void getPosDir(float s, out vec2 pos, out vec2 dir) {
    s = mod(s, 134.0);
    pos = corners[0];
    dir = vec2(1.0, 0.0);
    for (int i = 0; i < 24; i++) {
        if (s <= cumDist[i + 1]) {
            float t = (s - cumDist[i]) / (cumDist[i + 1] - cumDist[i]);
            pos = mix(corners[i], corners[i + 1], t);
            dir = normalize(corners[i + 1] - corners[i]);
            return;
        }
    }
}

// -----------------------------------------------------------------------------
// 3. Retro 3x5 Pixel Font HUD Renderer
// -----------------------------------------------------------------------------
int getGlyph(int ch) {
    switch (ch) {
        case 48: return 0x7B6F; // 0
        case 49: return 0x2C97; // 1
        case 50: return 0x73E7; // 2
        case 51: return 0x73CF; // 3
        case 52: return 0x5BC9; // 4
        case 53: return 0x79CF; // 5
        case 54: return 0x79EF; // 6
        case 55: return 0x7292; // 7
        case 56: return 0x7BEF; // 8
        case 57: return 0x7BCF; // 9
        case 85: return 0x5B6F; // U
        case 80: return 0x7BE4; // P
        case 72: return 0x5BED; // H
        case 73: return 0x7497; // I
        case 71: return 0x796F; // G
        case 83: return 0x79CF; // S
        case 67: return 0x7927; // C
        case 79: return 0x7B6F; // O
        case 82: return 0x7BF5; // R
        case 69: return 0x79E7; // E
        case 65: return 0x7BED; // A
        case 68: return 0x6B6E; // D
        case 89: return 0x5A92; // Y
        case 33: return 0x2482; // !
        default: return 0;
    }
}

float drawChar(vec2 p, int ch) {
    if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) return 0.0;
    int gx = int(clamp(p.x * 3.0, 0.0, 2.0));
    int gy = int(clamp(p.y * 5.0, 0.0, 4.0));
    int glyph = getGlyph(ch);
    int row = (glyph >> ((4 - gy) * 3)) & 7;
    return float((row >> (2 - gx)) & 1);
}

// -----------------------------------------------------------------------------
// 4. Main CapMan Arcade Shader
// -----------------------------------------------------------------------------
vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    vec3 color = vec3(0.0);

    // Screen geometry: 28x36 arcade aspect (~0.777)
    float screenH = 1.84;
    float rowH = screenH / 36.0; // Tile dimension in centered space
    vec2 arcadeOrigin = vec2(-14.0 * rowH, 0.92 - 3.0 * rowH);

    // Map screen centered coordinates to maze tile coordinates [0..28] x [-3..33]
    vec2 mazeCoord = vec2(
        (centered.x - arcadeOrigin.x) / rowH,
        (arcadeOrigin.y - centered.y) / rowH
    );

    // Arcade CRT bezel bounds
    bool insideMonitor = (mazeCoord.x >= -0.2 && mazeCoord.x <= 28.2 &&
                          mazeCoord.y >= -3.2 && mazeCoord.y <= 33.2);

    // -------------------------------------------------------------------------
    // A. Cabinet Frame, Bezel, & Side Marquee Art
    // -------------------------------------------------------------------------
    if (!insideMonitor) {
        vec2 cabCoord = centered;
        float bezelDistX = max(0.0, abs(mazeCoord.x - 14.0) - 14.2);
        float bezelDistY = max(0.0, abs(mazeCoord.y - 15.0) - 18.2);
        float bezelDist = max(bezelDistX, bezelDistY);

        // Dark textured arcade cabinet bezel
        vec3 cabCol = vec3(0.025, 0.028, 0.04);
        float bezelShade = 1.0 - smoothstep(0.0, 1.5, bezelDist);
        cabCol += vec3(0.02, 0.025, 0.045) * bezelShade;

        // Vintage arcade cabinet side graphics / stripes
        float sideX = abs(centered.x);
        if (sideX > 0.78) {
            float stripe1 = sin((sideX - 0.78) * 45.0 + cabCoord.y * 3.0) * 0.5 + 0.5;
            float stripe2 = sin((sideX - 0.78) * 30.0 - cabCoord.y * 2.0) * 0.5 + 0.5;
            vec3 neonBlue = vec3(0.05, 0.25, 0.85);
            vec3 neonMagenta = vec3(0.85, 0.05, 0.45);
            cabCol += mix(neonBlue, neonMagenta, stripe2) * (stripe1 * 0.12);
        }

        // CRT bezel edge bevel highlight & shadow
        if (bezelDist < 0.8) {
            float edgeGrad = clamp(1.0 - bezelDist / 0.8, 0.0, 1.0);
            cabCol += vec3(0.06, 0.08, 0.12) * edgeGrad * (0.8 + 0.2 * sin(centered.y * 10.0));
        }

        // Vignette on outer edge of cabinet
        cabCol *= clamp(1.6 - length(centered * vec2(0.8, 1.0)), 0.0, 1.0);
        return vec4(cabCol * intensity, alpha);
    }

    // -------------------------------------------------------------------------
    // B. Autonomous Game Simulation State
    // -------------------------------------------------------------------------
    float pacSpeed = 5.5;
    float pacDist = mod(t * pacSpeed, 134.0);

    vec2 pacPos, pacDir;
    getPosDir(pacDist, pacPos, pacDir);

    // Ghost states (Blinky, Pinky, Inky, Clyde)
    vec2 ghostPos[4];
    vec2 ghostDir[4];
    float ghostTrailOffsets[4] = float[4](3.2, 5.8, 8.4, 11.0);
    vec3 ghostNormalColors[4] = vec3[4](
        vec3(1.0, 0.08, 0.08),  // Blinky: Red
        vec3(1.0, 0.72, 0.88),  // Pinky: Pink
        vec3(0.0, 0.88, 1.0),   // Inky: Cyan
        vec3(1.0, 0.55, 0.08)   // Clyde: Orange
    );

    // Scared ghost mode triggered every 22 seconds for 8 seconds
    float cycleTime = mod(t, 22.0);
    bool isScared = (cycleTime > 12.0 && cycleTime < 20.0);
    bool isFlashing = (cycleTime >= 17.5 && cycleTime < 20.0) && (fract(t * 4.5) > 0.5);

    for (int i = 0; i < 4; i++) {
        float gDist = isScared ? (pacDist + 4.0 + float(i) * 2.5) : (pacDist - ghostTrailOffsets[i]);
        getPosDir(gDist, ghostPos[i], ghostDir[i]);
    }

    // -------------------------------------------------------------------------
    // C. Maze Rendering (Tiles [0..28] x [0..31])
    // -------------------------------------------------------------------------
    ivec2 tile = ivec2(floor(mazeCoord));
    vec2 f = fract(mazeCoord);

    if (tile.y >= 0 && tile.y < 31 && tile.x >= 0 && tile.x < 28) {
        bool w = isWall(tile.x, tile.y);

        if (w) {
            // Check 4 cardinal neighbors
            bool wl = isWall(tile.x - 1, tile.y);
            bool wr = isWall(tile.x + 1, tile.y);
            bool wt = isWall(tile.x, tile.y - 1);
            bool wb = isWall(tile.x, tile.y + 1);

            float d = 999.0;
            if (!wl) d = min(d, f.x);
            if (!wr) d = min(d, 1.0 - f.x);
            if (!wt) d = min(d, f.y);
            if (!wb) d = min(d, 1.0 - f.y);

            // Filleted corner contours
            if (wl && wt && !isWall(tile.x - 1, tile.y - 1)) d = min(d, length(f));
            if (wr && wt && !isWall(tile.x + 1, tile.y - 1)) d = min(d, length(vec2(1.0 - f.x, f.y)));
            if (wl && wb && !isWall(tile.x - 1, tile.y + 1)) d = min(d, length(vec2(f.x, 1.0 - f.y)));
            if (wr && wb && !isWall(tile.x + 1, tile.y + 1)) d = min(d, length(vec2(1.0 - f.x, 1.0 - f.y)));

            // Classic arcade neon double lines
            float lineCenter = 0.18;
            float lineDist = abs(d - lineCenter);
            float lineMask = 1.0 - smoothstep(0.03, 0.075, lineDist);
            float neonGlow = exp(-lineDist * 14.0) * 0.35;

            vec3 blueNeon = vec3(0.13, 0.16, 0.95);
            vec3 glowColor = vec3(0.04, 0.08, 0.55);
            color = blueNeon * lineMask + glowColor * neonGlow;

            // Deep arcade interior for solid wall blocks
            if (d > lineCenter + 0.08) {
                color = vec3(0.005, 0.008, 0.025);
            }
        } else {
            // Corridor background
            color = vec3(0.0);

            // Ghost house door in row 12, columns 13 and 14
            if (tile.y == 12 && (tile.x == 13 || tile.x == 14)) {
                float doorDist = abs(f.y - 0.82);
                float doorMask = 1.0 - smoothstep(0.03, 0.07, doorDist);
                vec3 doorPink = vec3(1.0, 0.72, 0.88);
                color += doorPink * doorMask + doorPink * exp(-doorDist * 16.0) * 0.4;
            }

            // Pellets & Power Energizers
            if (isPelletTile(tile.x, tile.y)) {
                bool isEnergizer = isPowerPellet(tile.x, tile.y);
                float dCenter = length(f - 0.5);

                // Pac-Man eating detection
                float distToPac = length(vec2(tile) + 0.5 - pacPos);
                if (distToPac > 0.55) {
                    if (isEnergizer) {
                        float pulse = 0.33 + 0.07 * sin(t * 8.5);
                        float energizerMask = 1.0 - smoothstep(pulse - 0.04, pulse + 0.02, dCenter);
                        float energizerGlow = exp(-dCenter * 6.5) * 0.55;
                        vec3 energizerCol = vec3(1.0, 0.95, 0.82);
                        color += energizerCol * energizerMask + vec3(1.0, 0.8, 0.5) * energizerGlow;
                    } else {
                        float pelletR = 0.11;
                        float pelletMask = 1.0 - smoothstep(pelletR - 0.02, pelletR + 0.02, dCenter);
                        vec3 pelletCol = vec3(1.0, 0.85, 0.72);
                        color += pelletCol * pelletMask;
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // D. Pac-Man Rendering
    // -------------------------------------------------------------------------
    vec2 dp = mazeCoord - pacPos;
    float rp = length(dp);
    if (rp < 0.6) {
        float ang = atan(dp.y, dp.x);
        float dirAngle = atan(pacDir.y, pacDir.x);
        float relAng = mod(ang - dirAngle + PI, TWO_PI) - PI;

        // Animated chomping mouth (waka-waka)
        float mouthAngle = 0.58 * abs(sin(t * 16.0));

        float pacBody = 1.0 - smoothstep(0.42, 0.45, rp);
        float pacMouth = smoothstep(mouthAngle - 0.04, mouthAngle + 0.02, abs(relAng));
        float pacMask = pacBody * pacMouth;

        vec3 pacYellow = vec3(1.0, 1.0, 0.0);
        float pacGlow = exp(-rp * 4.5) * 0.35;

        color = mix(color, pacYellow, pacMask);
        color += vec3(0.5, 0.45, 0.0) * pacGlow;
    }

    // -------------------------------------------------------------------------
    // E. 4 Classic Ghosts Rendering
    // -------------------------------------------------------------------------
    for (int i = 0; i < 4; i++) {
        vec2 dg = mazeCoord - ghostPos[i];
        if (length(dg) < 0.7) {
            // Scalloped ruffled skirt at bottom
            float arch = 0.08 * abs(cos((dg.x / 0.42) * PI * 2.5 + t * 10.0 + float(i)));
            float skirtBottom = 0.38 - arch;

            float dHead = length(dg - vec2(0.0, -0.05)) - 0.42;
            float dBody = max(abs(dg.x) - 0.42, max(dg.y - skirtBottom, -dg.y - 0.05));
            float dGhost = min(max(dHead, -dg.y - 0.05), dBody);
            float ghostMask = 1.0 - smoothstep(-0.01, 0.03, dGhost);

            // Ghost color selection
            vec3 gCol;
            if (isScared) {
                gCol = isFlashing ? vec3(0.92, 0.92, 0.98) : vec3(0.12, 0.16, 0.92);
            } else {
                gCol = ghostNormalColors[i];
            }

            color = mix(color, gCol, ghostMask);

            // Eyes & Pupils
            if (!isScared) {
                vec2 eyeL = dg - (vec2(-0.16, -0.08) + ghostDir[i] * 0.05);
                vec2 eyeR = dg - (vec2(0.16, -0.08) + ghostDir[i] * 0.05);

                float eyeLMask = 1.0 - smoothstep(0.11, 0.13, length(eyeL));
                float eyeRMask = 1.0 - smoothstep(0.11, 0.13, length(eyeR));
                float eyesWhite = clamp(eyeLMask + eyeRMask, 0.0, 1.0);
                color = mix(color, vec3(1.0), eyesWhite);

                // Blue pupils looking in direction of travel
                vec2 pupilL = eyeL - ghostDir[i] * 0.045;
                vec2 pupilR = eyeR - ghostDir[i] * 0.045;
                float pupilMask = clamp((1.0 - smoothstep(0.05, 0.065, length(pupilL))) +
                                        (1.0 - smoothstep(0.05, 0.065, length(pupilR))), 0.0, 1.0);
                color = mix(color, vec3(0.08, 0.15, 0.92), pupilMask);
            } else {
                // Scared ghost white dot eyes
                float eyeDot = clamp((1.0 - smoothstep(0.04, 0.06, length(dg - vec2(-0.14, -0.08)))) +
                                     (1.0 - smoothstep(0.04, 0.06, length(dg - vec2(0.14, -0.08)))), 0.0, 1.0);
                color = mix(color, vec3(1.0, 0.85, 0.4), eyeDot);

                // Scared wavy mouth
                float mouthWave = 0.03 * sin(dg.x * 24.0 + t * 6.0);
                float mouthLine = 1.0 - smoothstep(0.02, 0.04, abs(dg.y - (0.16 + mouthWave)));
                if (abs(dg.x) < 0.24) {
                    color = mix(color, vec3(1.0, 0.72, 0.5), mouthLine);
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // F. Arcade HUD: "1UP", Score, "HIGH SCORE", "READY!"
    // -------------------------------------------------------------------------
    // Top HUD line 1: "1UP" and "HIGH SCORE"
    if (mazeCoord.y >= -2.8 && mazeCoord.y <= -1.8) {
        vec2 p1up = vec2((mazeCoord.x - 3.0) / 1.0, (mazeCoord.y - (-2.8)) / 1.0);
        float t1 = drawChar(p1up - vec2(0.0, 0.0), 49); // '1'
        float t2 = drawChar(p1up - vec2(1.2, 0.0), 85); // 'U'
        float t3 = drawChar(p1up - vec2(2.4, 0.0), 80); // 'P'
        float m1up = clamp(t1 + t2 + t3, 0.0, 1.0);
        color = mix(color, vec3(1.0, 0.15, 0.15), m1up);

        vec2 pHS = vec2((mazeCoord.x - 13.5) / 0.85, (mazeCoord.y - (-2.8)) / 1.0);
        float h1 = drawChar(pHS - vec2(0.0, 0.0), 72);  // 'H'
        float h2 = drawChar(pHS - vec2(1.1, 0.0), 73);  // 'I'
        float h3 = drawChar(pHS - vec2(2.2, 0.0), 71);  // 'G'
        float h4 = drawChar(pHS - vec2(3.3, 0.0), 72);  // 'H'
        float h5 = drawChar(pHS - vec2(5.0, 0.0), 83);  // 'S'
        float h6 = drawChar(pHS - vec2(6.1, 0.0), 67);  // 'C'
        float h7 = drawChar(pHS - vec2(7.2, 0.0), 79);  // 'O'
        float h8 = drawChar(pHS - vec2(8.3, 0.0), 82);  // 'R'
        float h9 = drawChar(pHS - vec2(9.4, 0.0), 69);  // 'E'
        float mHS = clamp(h1 + h2 + h3 + h4 + h5 + h6 + h7 + h8 + h9, 0.0, 1.0);
        color = mix(color, vec3(1.0, 0.15, 0.15), mHS);
    }

    // Top HUD line 2: Current Score & High Score
    if (mazeCoord.y >= -1.5 && mazeCoord.y <= -0.5) {
        vec2 pScore = vec2((mazeCoord.x - 3.2) / 0.9, (mazeCoord.y - (-1.5)) / 1.0);
        float s1 = drawChar(pScore - vec2(0.0, 0.0), 49); // '1'
        float s2 = drawChar(pScore - vec2(1.1, 0.0), 52); // '4'
        float s3 = drawChar(pScore - vec2(2.2, 0.0), 56); // '8'
        float s4 = drawChar(pScore - vec2(3.3, 0.0), 50); // '2'
        float s5 = drawChar(pScore - vec2(4.4, 0.0), 48); // '0'
        float mScore = clamp(s1 + s2 + s3 + s4 + s5, 0.0, 1.0);
        color = mix(color, vec3(1.0), mScore);

        vec2 pHScore = vec2((mazeCoord.x - 17.0) / 0.9, (mazeCoord.y - (-1.5)) / 1.0);
        float hs1 = drawChar(pHScore - vec2(0.0, 0.0), 51); // '3'
        float hs2 = drawChar(pHScore - vec2(1.1, 0.0), 51); // '3'
        float hs3 = drawChar(pHScore - vec2(2.2, 0.0), 51); // '3'
        float hs4 = drawChar(pHScore - vec2(3.3, 0.0), 51); // '3'
        float hs5 = drawChar(pHScore - vec2(4.4, 0.0), 48); // '0'
        float mHScore = clamp(hs1 + hs2 + hs3 + hs4 + hs5, 0.0, 1.0);
        color = mix(color, vec3(1.0), mHScore);
    }

    // Center "READY!" in yellow below ghost house
    if (mazeCoord.y >= 17.2 && mazeCoord.y <= 18.2 && mazeCoord.x >= 11.0 && mazeCoord.x <= 17.0) {
        vec2 pReady = vec2((mazeCoord.x - 11.0) / 0.9, (mazeCoord.y - 17.2) / 1.0);
        float r1 = drawChar(pReady - vec2(0.0, 0.0), 82); // 'R'
        float r2 = drawChar(pReady - vec2(1.1, 0.0), 69); // 'E'
        float r3 = drawChar(pReady - vec2(2.2, 0.0), 65); // 'A'
        float r4 = drawChar(pReady - vec2(3.3, 0.0), 68); // 'D'
        float r5 = drawChar(pReady - vec2(4.4, 0.0), 89); // 'Y'
        float r6 = drawChar(pReady - vec2(5.5, 0.0), 33); // '!'
        float mReady = clamp(r1 + r2 + r3 + r4 + r5 + r6, 0.0, 1.0);
        color = mix(color, vec3(1.0, 1.0, 0.0), mReady);
    }

    // Bottom HUD: Extra Lives (mini Pac-Man icons) & Cherry Fruit
    if (mazeCoord.y >= 31.2 && mazeCoord.y <= 33.2) {
        // 3 Extra lives icons
        for (int l = 0; l < 3; l++) {
            vec2 lifePos = vec2(2.5 + float(l) * 2.0, 32.2);
            vec2 dLife = mazeCoord - lifePos;
            float rLife = length(dLife);
            if (rLife < 0.4) {
                float angLife = atan(dLife.y, dLife.x);
                float relAngLife = mod(angLife - PI + PI, TWO_PI) - PI; // Facing left
                float lifeBody = 1.0 - smoothstep(0.35, 0.38, rLife);
                float lifeMouth = smoothstep(0.3, 0.35, abs(relAngLife));
                color = mix(color, vec3(1.0, 1.0, 0.0), lifeBody * lifeMouth);
            }
        }

        // Bonus Cherry fruit icon at bottom right
        vec2 cherryCenter = vec2(25.0, 32.2);
        vec2 dCherry = mazeCoord - cherryCenter;

        // Two cherry berries
        float berry1 = 1.0 - smoothstep(0.24, 0.27, length(dCherry - vec2(-0.2, 0.2)));
        float berry2 = 1.0 - smoothstep(0.24, 0.27, length(dCherry - vec2(0.22, 0.25)));
        float cherries = clamp(berry1 + berry2, 0.0, 1.0);
        color = mix(color, vec3(0.95, 0.04, 0.12), cherries);

        // Shiny highlights on berries
        float spec1 = 1.0 - smoothstep(0.04, 0.07, length(dCherry - vec2(-0.26, 0.14)));
        float spec2 = 1.0 - smoothstep(0.04, 0.07, length(dCherry - vec2(0.16, 0.19)));
        color = mix(color, vec3(1.0), clamp(spec1 + spec2, 0.0, 1.0));

        // Brown stems
        float stem1 = 1.0 - smoothstep(0.03, 0.06, abs(length(dCherry - vec2(0.1, -0.15)) - 0.45));
        if (dCherry.y < 0.2 && dCherry.x > -0.25 && dCherry.x < 0.25) {
            color = mix(color, vec3(0.55, 0.35, 0.15), stem1);
        }

        // Green leaf
        float leaf = 1.0 - smoothstep(0.08, 0.12, length(dCherry - vec2(0.18, -0.32)));
        color = mix(color, vec3(0.1, 0.85, 0.2), leaf);
    }

    // -------------------------------------------------------------------------
    // G. CRT Retro Arcade Post-Processing
    // -------------------------------------------------------------------------
    // Scanlines
    float scanline = 0.94 + 0.06 * sin(centered.y * resolution.y * 1.5);
    color *= scanline;

    // Subtle CRT monitor glass curvature vignette
    vec2 crtUV = (mazeCoord - vec2(14.0, 15.0)) / vec2(14.5, 18.5);
    float crtVignette = clamp(1.15 - dot(crtUV, crtUV) * 0.25, 0.0, 1.0);
    color *= crtVignette;

    // Phosphor bloom
    color += color * 0.12;

    color = clamp(color, 0.0, 1.0) * intensity;
    return vec4(color, alpha);
}