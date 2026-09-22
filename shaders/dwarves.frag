#include "base/common.glsl"

// dwarves - Underground Great Forge of Khazad-dum with Master Dwarf Smith at the Anvil

mat2 rot2D(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float sdBox2D(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdUnevenCapsule(vec2 p, float r1, float r2, float h) {
    p.x = abs(p.x);
    float b = (r1 - r2) / h;
    float a = sqrt(max(0.0, 1.0 - b * b));
    float k = dot(p, vec2(-b, a));
    if (k < 0.0) return length(p) - r1;
    if (k > a * h) return length(p - vec2(0.0, h)) - r2;
    return dot(p, vec2(a, b)) - r1;
}


float fillSDF(float d, float blur) {
    return 1.0 - smoothstep(-blur, blur, d);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    vec2 p = centered;

    // Heat shimmer from the forge
    float shimmer = sin(p.y * 22.0 - t * 4.0) * 0.004 * clamp(0.5 - abs(p.x) * 0.8, 0.0, 1.0);
    p.x += shimmer;

    // -------------------------------------------------------------
    // 1. Vaulted Stone Cavern & Forge Ambient Glow
    // -------------------------------------------------------------
    vec3 col = vec3(0.04, 0.025, 0.02); // Deep dark subterranean stone
    
    // Central blazing furnace radiance
    vec2 furnacePos = vec2(0.0, 0.22);
    float dFurnaceCenter = length(p - furnacePos);
    float forgeFlicker = 0.85 + 0.15 * sin(t * 9.0) * cos(t * 15.0);
    
    vec3 ambientGlow = vec3(1.0, 0.42, 0.08) * (0.65 / (1.0 + dFurnaceCenter * 2.8)) * forgeFlicker;
    col += ambientGlow;

    // Distant vaulted ceiling arches
    float archY = 0.65 - pow(p.x * 0.7, 2.0) * 0.35;
    if (p.y > archY) {
        float archDepth = clamp((p.y - archY) / 0.25, 0.0, 1.0);
        col = mix(col, vec3(0.025, 0.015, 0.012), archDepth * 0.8);
    }

    // -------------------------------------------------------------
    // 2. Colossal Faceted Dwarven Pillars with Glowing Runes
    // -------------------------------------------------------------
    for (float side = -1.0; side <= 1.0; side += 2.0) {
        for (float colIdx = 1.0; colIdx <= 3.0; colIdx += 1.0) {
            float px = side * (0.85 + colIdx * 0.55);
            float pw = 0.16 - colIdx * 0.025;
            float pillarD = abs(p.x - px) - pw;
            
            if (pillarD < 0.0) {
                // Stone pillar body
                vec3 pilCol = mix(vec3(0.06, 0.04, 0.035), vec3(0.12, 0.08, 0.06), smoothstep(-pw, 0.0, -abs(p.x - px)));
                
                // Rim lighting from central forge
                float rimL = smoothstep(0.0, -pw * 0.8, (p.x - px) * side);
                pilCol += vec3(1.0, 0.45, 0.1) * rimL * 0.45 * forgeFlicker;
                
                // Glowing ancient Dwarven Runes on pillars
                float runeY = fract(p.y * 3.5 + colIdx * 0.3) - 0.5;
                float runeX = (p.x - px) / pw;
                float runeDist = length(vec2(runeX, runeY * 1.5)) - 0.22;
                float runeGlow = exp(-abs(runeDist) * 35.0);
                
                // Pulsing magical cyan/gold rune light
                vec3 runeCol = mix(vec3(0.1, 0.85, 1.0), vec3(1.0, 0.75, 0.2), sin(t * 2.0 + colIdx) * 0.5 + 0.5);
                pilCol += runeCol * runeGlow * (0.7 + 0.3 * sin(t * 3.0 + colIdx * 2.0));
                
                col = mix(col, pilCol, fillSDF(pillarD, 0.005));
            }
        }
    }

    // -------------------------------------------------------------
    // 3. The Great Smelting Furnace & Molten Crucible
    // -------------------------------------------------------------
    vec2 fPos = p - furnacePos;
    float dFurnaceArch = length(fPos) - 0.38;
    dFurnaceArch = max(dFurnaceArch, -fPos.y - 0.05);
    
    // Glowing hearth interior
    if (dFurnaceArch < 0.0) {
        float fCore = exp(-length(fPos) * 6.5);
        vec3 hearthFire = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.95, 0.45), fCore);
        hearthFire += vec3(0.3) * sin(fPos.x * 25.0 + t * 8.0) * sin(fPos.y * 25.0);
        col = mix(col, hearthFire, fillSDF(dFurnaceArch, 0.01));
    }
    
    // Heavy wrought-iron furnace hood & arch rim
    float dFurnaceFrame = abs(dFurnaceArch) - 0.035;
    if (dFurnaceFrame < 0.01 && fPos.y > -0.05) {
        vec3 frameCol = vec3(0.18, 0.14, 0.12);
        col = mix(col, frameCol, fillSDF(dFurnaceFrame, 0.004));
    }

    // Molten stream pouring from forge to the side
    vec2 streamP = p - vec2(-0.25, 0.05);
    float dStream = sdSegment(streamP, vec2(0.0, 0.15), vec2(-0.12, -0.45)) - 0.018;
    if (dStream < 0.02) {
        vec3 moltenGold = mix(vec3(1.0, 0.3, 0.02), vec3(1.0, 0.9, 0.3), sin(streamP.y * 30.0 - t * 10.0) * 0.5 + 0.5);
        col = mix(col, moltenGold, fillSDF(dStream, 0.005));
    }

    // -------------------------------------------------------------
    // 4. Heavy Dwarven Anvil & Glowing Ingot
    // -------------------------------------------------------------
    vec2 aPos = p - vec2(-0.10, -0.45);
    
    // Anvil Waist & Base
    float dAnvilBase = sdBox2D(aPos - vec2(0.0, -0.12), vec2(0.24, 0.06)) - 0.02;
    float dAnvilWaist = sdBox2D(aPos - vec2(0.0, -0.02), vec2(0.12, 0.08)) - 0.01;
    float dAnvilFace = sdBox2D(aPos - vec2(0.02, 0.08), vec2(0.20, 0.05)) - 0.01;
    // Anvil Horn (tapered point on left)
    vec2 hornP = aPos - vec2(-0.26, 0.08);
    float dAnvilHorn = sdSegment(hornP, vec2(0.08, 0.0), vec2(-0.10, 0.02)) - 0.035;
    
    float dAnvil = min(dAnvilBase, min(dAnvilWaist, min(dAnvilFace, dAnvilHorn)));
    if (dAnvil < 0.02) {
        vec3 anvilSteel = vec3(0.22, 0.20, 0.19);
        // Specular highlight from forge
        anvilSteel += vec3(0.25, 0.12, 0.04) * clamp((aPos.y + 0.1) * 2.0, 0.0, 1.0);
        col = mix(col, anvilSteel, fillSDF(dAnvil, 0.004));
    }

    // Red-hot metal ingot resting on anvil
    vec2 ingotP = aPos - vec2(0.04, 0.14);
    float dIngot = sdBox2D(ingotP, vec2(0.08, 0.025)) - 0.005;
    if (dIngot < 0.015) {
        vec3 ingotCol = mix(vec3(1.0, 0.20, 0.02), vec3(1.0, 0.85, 0.20), (1.0 - length(ingotP) * 8.0));
        col = mix(col, ingotCol, fillSDF(dIngot, 0.003));
        col += vec3(1.0, 0.4, 0.08) * exp(-dIngot * 40.0) * 0.8;
    }

    // -------------------------------------------------------------
    // 5. Master Dwarf Smith (Hero Foreground Character)
    // -------------------------------------------------------------
    vec2 dPos = vec2(0.28, -0.38);
    vec2 dp = p - dPos;

    // Stout, broad muscular body
    float dBody = sdBox2D(dp - vec2(0.0, 0.04), vec2(0.22, 0.26)) - 0.04;

    // Heavy Pauldrons (riveted iron shoulder armor)
    vec2 pauldLP = dp - vec2(-0.24, 0.20);
    float dPauldL = sdBox2D(pauldLP, vec2(0.10, 0.08)) - 0.03;
    vec2 pauldRP = dp - vec2(0.24, 0.20);
    float dPauldR = sdBox2D(pauldRP, vec2(0.10, 0.08)) - 0.03;

    // Dwarven Great-Helm with Horns / Crest
    vec2 helmP = dp - vec2(0.0, 0.40);
    float dHelm = sdCircle(helmP, 0.16);
    dHelm = max(dHelm, -(helmP.y - 0.02)); // Visor cut
    
    // Golden Helm Crest / Brow
    vec2 browP = helmP - vec2(0.0, 0.02);
    float dBrow = sdBox2D(browP, vec2(0.13, 0.035)) - 0.01;
    
    // Curved Ram-like Horns on Helm
    vec2 hornL = helmP - vec2(-0.14, 0.06);
    float dHornL = sdSegment(hornL, vec2(0.0, 0.0), vec2(-0.12, 0.12)) - 0.028;
    vec2 hornR = helmP - vec2(0.14, 0.06);
    float dHornR = sdSegment(hornR, vec2(0.0, 0.0), vec2(0.12, 0.12)) - 0.028;
    float dHorns = min(dHornL, dHornR);

    // Glorious Braided Dwarven Beard tapering down over chest
    vec2 beardP = dp - vec2(0.0, 0.28);
    vec2 bp = vec2(beardP.x, -beardP.y);
    float dBeard = sdUnevenCapsule(bp, 0.16, 0.05, 0.38);
    
    // Golden Beard Rings / Clasps
    vec2 ring1P = dp - vec2(0.0, 0.06);
    float dRing1 = sdBox2D(ring1P, vec2(0.055, 0.020)) - 0.005;
    vec2 ring2P = dp - vec2(0.0, -0.05);
    float dRing2 = sdBox2D(ring2P, vec2(0.042, 0.016)) - 0.005;


    // Muscular Arm swinging Smithing Hammer
    // Dynamic hammer strike animation
    float strikePhase = fract(t * 1.8);
    float strikeAngle = -0.4 + sin(strikePhase * 6.28318) * 0.45;
    if (strikePhase > 0.65) strikeAngle = -0.75; // impact hold
    
    vec2 armP = dp - vec2(-0.25, 0.15);
    armP = rot2D(strikeAngle) * armP;
    float dArm = sdSegment(armP, vec2(0.0, 0.0), vec2(-0.18, 0.22)) - 0.065;

    // Massive Dwarven Smithing Hammer
    vec2 hammerP = armP - vec2(-0.18, 0.22);
    float dShaft = sdSegment(hammerP, vec2(0.0, -0.15), vec2(0.0, 0.38)) - 0.018;
    vec2 headBlock = hammerP - vec2(0.0, 0.32);
    float dHammerHead = sdBox2D(headBlock, vec2(0.12, 0.07)) - 0.015;
    float dHammer = min(dShaft, dHammerHead);

    // Combine Dwarf Elements
    float dwarfArmor = min(dBody, min(dPauldL, min(dPauldR, min(dHelm, dBrow))));
    float dwarfTotal = min(dwarfArmor, min(dHorns, min(dBeard, min(dArm, dHammer))));

    if (dwarfTotal < 0.02) {
        vec3 dPixel = vec3(0.18, 0.15, 0.13); // Dark worked iron armor
        
        if (min(dRing1, dRing2) < 0.01 || dBrow < 0.01) {
            // Ornate Dwarven Gold Accents
            dPixel = vec3(0.92, 0.75, 0.25);
        } else if (dBeard < dwarfArmor && dBeard < dHammer) {
            // Fiery Copper/Auburn Braided Beard
            dPixel = vec3(0.55, 0.22, 0.08);
            // Texture braids
            float braidTexture = sin(dp.x * 45.0) * sin(dp.y * 30.0);
            dPixel += vec3(0.08) * smoothstep(0.3, 0.8, braidTexture);
        } else if (dHorns < dwarfArmor) {
            // Carved Ivory/Bone Horns
            dPixel = vec3(0.78, 0.72, 0.62);
        } else if (dArm < dwarfArmor) {
            // Ruddy muscular skin
            dPixel = vec3(0.72, 0.48, 0.36);
        } else if (dHammer < dwarfArmor) {
            // Heavy runic hammer
            dPixel = vec3(0.35, 0.33, 0.32);
            // Glowing rune on hammer face
            float hr = length(headBlock) - 0.035;
            if (hr < 0.01) {
                dPixel = vec3(1.0, 0.8, 0.3) * 1.5;
            }
        }

        // Warm directional lighting from the blazing forge (left side of dwarf)
        float forgeLight = clamp((-dp.x * 1.1 + 0.4), 0.0, 1.0);
        vec3 rimForge = vec3(1.0, 0.50, 0.12) * forgeFlicker * 1.2;
        dPixel += rimForge * pow(forgeLight, 1.5) * 0.75;

        // Glowing eyes behind helm slit
        vec2 eyeLP = helmP - vec2(-0.045, -0.02);
        vec2 eyeRP = helmP - vec2(0.045, -0.02);
        float dEye = min(sdCircle(eyeLP, 0.012), sdCircle(eyeRP, 0.012));
        if (dEye < 0.008) {
            dPixel = vec3(0.2, 0.85, 1.0); // Piercing blue eyes
        }

        col = mix(col, dPixel, fillSDF(dwarfTotal, 0.004));
    }

    // -------------------------------------------------------------
    // 6. Flying Smithing Sparks & Rising Embers
    // -------------------------------------------------------------
    vec2 anvilImpact = vec2(-0.06, -0.31);
    for (float s = 0.0; s < 32.0; s += 1.0) {
        float sSpeed = 0.5 + sin(s * 9.1) * 0.25;
        float sLife = fract(t * sSpeed * 1.2 + s * 0.07);
        float sAngle = 1.2 + sin(s * 13.7) * 1.1; // fountain upward
        vec2 sparkTraj = vec2(cos(sAngle), sin(sAngle)) * (sLife * 0.95);
        sparkTraj.y -= sLife * sLife * 0.5; // gravity arc
        
        vec2 sparkP = anvilImpact + sparkTraj;
        float dSpk = length(p - sparkP);
        float sparkBright = (1.0 - sLife) * exp(-dSpk * 95.0);
        vec3 sparkCol = mix(vec3(1.0, 0.85, 0.2), vec3(1.0, 0.25, 0.02), sLife);
        col += sparkCol * sparkBright * 2.2;
    }

    // Heavy stone floor
    float floorY = -0.62;
    if (p.y < floorY) {
        float flDepth = clamp((floorY - p.y) / 0.15, 0.0, 1.0);
        vec3 flCol = mix(vec3(0.07, 0.05, 0.04), vec3(0.03, 0.02, 0.015), flDepth);
        // Floor tile joints
        float tile = sin(p.x * 8.0) * sin(p.y * 12.0);
        flCol += vec3(0.02) * smoothstep(0.4, 0.8, tile);
        col = mix(col, flCol, fillSDF(p.y - floorY, 0.004));
    }

    // Cavern vignette
    float vignette = clamp(1.5 - length(centered) * 0.5, 0.0, 1.0);
    col *= vignette;

    col = clamp(col, 0.0, 1.0) * intensity;
    return vec4(col, alpha);
}