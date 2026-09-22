#include "base/common.glsl"

// orcs - Menacing volcanic fortress with iron-clad orc warlord and marching horde

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

float fillSDF(float d, float blur) {
    return 1.0 - smoothstep(-blur, blur, d);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    vec2 p = centered;

    // Heat haze shimmer over scene
    float heatShimmer = sin(p.y * 20.0 - t * 3.5) * 0.005 * clamp((0.3 - p.y) * 1.5, 0.0, 1.0);
    p.x += heatShimmer;

    // -------------------------------------------------------------
    // 1. Volcanic Sky & Churning Smoke
    // -------------------------------------------------------------
    vec3 col = mix(vec3(0.08, 0.02, 0.01), vec3(0.24, 0.05, 0.01), clamp(0.5 - p.y * 0.5, 0.0, 1.0));
    
    // Churning ash clouds
    vec2 smokeUV = vec2(p.x * 0.7 + t * 0.04, p.y * 0.8 - t * 0.06);
    float smoke = fbm(vec3(smokeUV * 2.5, t * 0.08), 3);
    float smoke2 = fbm(vec3(smokeUV * 4.5 + 4.0, t * 0.12), 3);
    col += vec3(0.40, 0.10, 0.02) * smoothstep(0.2, 0.8, smoke) * clamp((p.y + 0.3) * 1.2, 0.0, 1.0);
    col += vec3(0.18, 0.04, 0.01) * smoothstep(0.3, 0.9, smoke2);

    // Volcanic flare pulses
    float fpBase = max(0.0, sin(t * 1.7) * sin(t * 3.1) * sin(t * 0.8));
    float flarePulse = fpBase * fpBase * fpBase * fpBase;
    col += vec3(0.6, 0.2, 0.06) * flarePulse * clamp((p.y + 0.2), 0.0, 1.0);

    // -------------------------------------------------------------
    // 2. Distant Volcanic Spire Fortress (Black Citadel)
    // -------------------------------------------------------------
    float mountainH = -0.15 + sin(p.x * 2.5) * 0.12 + sin(p.x * 7.1) * 0.05;
    if (p.y < mountainH) {
        float mDepth = clamp((mountainH - p.y) / 0.35, 0.0, 1.0);
        col = mix(col, vec3(0.06, 0.025, 0.02), mDepth * 0.9);
    }

    for (float i = -2.0; i <= 2.0; i += 1.0) {
        float tx = i * 0.75 + sin(i * 13.7) * 0.2;
        float tw = 0.09 - abs(i) * 0.015;
        float th = 0.45 + cos(i * 5.3) * 0.15;
        
        float towerDist = abs(p.x - tx) - tw * max(0.2, (th - p.y) / th);
        if (p.y < th && towerDist < 0.0) {
            vec3 towerCol = vec3(0.05, 0.02, 0.02);
            if (abs(i) < 0.5) {
                float eyeD = length(p - vec2(tx, th - 0.03));
                float eyeGlow = exp(-eyeD * 22.0);
                col += vec3(1.0, 0.4, 0.06) * eyeGlow * (0.8 + 0.2 * sin(t * 8.0));
            }
            col = mix(col, towerCol, fillSDF(towerDist, 0.006));
        }
    }

    // -------------------------------------------------------------
    // 3. Marching Orc Horde (Silhouettes with spears & banners)
    // -------------------------------------------------------------
    float ridgeMid = -0.32 + sin(p.x * 4.0) * 0.04;
    for (float k = 0.0; k < 18.0; k += 1.0) {
        float hx = -1.6 + k * 0.19 + sin(k * 2.3) * 0.03;
        float bob = sin(t * 3.5 + k * 1.5) * 0.015;
        float hy = ridgeMid + bob;
        
        // Spear
        vec2 spearTop = vec2(hx + 0.04, hy + 0.22);
        vec2 spearBot = vec2(hx, hy - 0.05);
        float dSpear = sdSegment(p, spearBot, spearTop) - 0.004;
        
        // Head / Helm
        float dHead = sdCircle(p - vec2(hx, hy + 0.06), 0.028);
        if (mod(k, 5.0) == 0.0) {
            vec2 bannerP = p - vec2(hx + 0.04, hy + 0.18);
            float banner = sdBox2D(bannerP, vec2(0.035, 0.045));
            dSpear = min(dSpear, banner);
        }
        
        float hordeFig = min(dSpear, dHead);
        col = mix(col, vec3(0.04, 0.02, 0.02), fillSDF(hordeFig, 0.004));
        
        // Torchlight
        if (mod(k, 3.0) == 1.0) {
            float torchD = length(p - vec2(hx + 0.04, hy + 0.14));
            float torchGlow = exp(-torchD * 30.0);
            col += vec3(1.0, 0.5, 0.1) * torchGlow * (0.7 + 0.3 * sin(t * 12.0 + k * 4.0));
        }
    }

    if (p.y < ridgeMid) {
        float rFade = clamp((ridgeMid - p.y) / 0.06, 0.0, 1.0);
        col = mix(col, vec3(0.05, 0.022, 0.02), rFade);
    }

    // -------------------------------------------------------------
    // 4. Molten Lava River & Fractures
    // -------------------------------------------------------------
    float lavaLevel = -0.58;
    float lavaDist = p.y - lavaLevel;
    float lavaFlicker = 0.85 + 0.15 * sin(t * 7.0) * sin(t * 13.0);
    
    vec3 lavaGlow = vec3(1.0, 0.35, 0.06) * (0.45 / (1.0 + abs(lavaDist) * 3.5)) * lavaFlicker;
    col += lavaGlow;

    if (p.y < lavaLevel) {
        vec2 lp = vec2(p.x * 2.5 + t * 0.1, (p.y - lavaLevel) * 4.5);
        float n1 = noise(lp * 2.5);
        float n2 = noise(lp * 5.0 + vec2(n1, t * 0.15));
        float veins = sin(lp.x * 5.0 + n1 * 3.5) * cos(lp.y * 4.0 + n2 * 3.5);
        float crack = smoothstep(-0.2, 0.45, veins);
        
        vec3 crustCol = vec3(0.09, 0.035, 0.025);
        vec3 fireCol = mix(vec3(1.0, 0.22, 0.01), vec3(1.0, 0.88, 0.32), smoothstep(0.4, 0.9, 1.0 - crack));
        vec3 river = mix(fireCol, crustCol, crack);
        river += vec3(0.7, 0.2, 0.0) * smoothstep(0.45, 0.25, crack) * 0.4;
        col = mix(col, river, clamp((lavaLevel - p.y) / 0.06, 0.0, 1.0));
    }

    // -------------------------------------------------------------
    // 5. Imposing Orc Warlord (Hero Foreground Character)
    // -------------------------------------------------------------
    vec2 oPos = vec2(0.20, -0.42);
    vec2 op = p - oPos;


    // Muscular Torso & Spiked Iron Armor
    float dTorso = sdBox2D(op - vec2(0.0, 0.05), vec2(0.24, 0.28)) - 0.04;
    dTorso = max(dTorso, -(op.y - 0.18 + abs(op.x) * 0.5));
    
    // Spiked Pauldrons (Shoulder Guards)
    vec2 pLeft = op - vec2(-0.30, 0.22);
    pLeft = rot2D(0.25) * pLeft;
    float dPauldronL = sdBox2D(pLeft, vec2(0.12, 0.09)) - 0.03;
    float dSpikeL1 = sdSegment(pLeft, vec2(-0.06, 0.08), vec2(-0.16, 0.22)) - 0.018;
    float dSpikeL2 = sdSegment(pLeft, vec2(0.04, 0.08), vec2(0.02, 0.25)) - 0.016;
    dPauldronL = min(dPauldronL, min(dSpikeL1, dSpikeL2));

    vec2 pRight = op - vec2(0.30, 0.22);
    pRight = rot2D(-0.25) * pRight;
    float dPauldronR = sdBox2D(pRight, vec2(0.12, 0.09)) - 0.03;
    float dSpikeR1 = sdSegment(pRight, vec2(0.06, 0.08), vec2(0.16, 0.22)) - 0.018;
    float dSpikeR2 = sdSegment(pRight, vec2(-0.04, 0.08), vec2(-0.02, 0.25)) - 0.016;
    dPauldronR = min(dPauldronR, min(dSpikeR1, dSpikeR2));

    // Orc Head / Neck
    float dNeck = sdBox2D(op - vec2(0.0, 0.28), vec2(0.14, 0.12));
    vec2 headP = op - vec2(0.0, 0.44);
    float dHead = sdCircle(headP, 0.15);

    // Horned Iron War-Helmet
    float dHelm = sdCircle(headP - vec2(0.0, 0.04), 0.16);
    dHelm = max(dHelm, -(headP.y - 0.02));
    vec2 hornL = headP - vec2(-0.13, 0.08);
    float dHornL = sdSegment(hornL, vec2(0.0, 0.0), vec2(-0.12, 0.14)) - 0.025;
    vec2 hornR = headP - vec2(0.13, 0.08);
    float dHornR = sdSegment(hornR, vec2(0.0, 0.0), vec2(0.12, 0.14)) - 0.025;
    dHelm = min(dHelm, min(dHornL, dHornR));

    // Heavy Tusked Lower Jaw
    vec2 jawP = headP - vec2(0.0, -0.09);
    float dJaw = sdBox2D(jawP, vec2(0.12, 0.08)) - 0.02;
    float dTuskL = sdSegment(headP, vec2(-0.07, -0.12), vec2(-0.09, 0.01)) - 0.018;
    float dTuskR = sdSegment(headP, vec2(0.07, -0.12), vec2(0.09, 0.01)) - 0.018;

    // Muscular Arm holding Battleaxe
    vec2 armP = op - vec2(-0.38, 0.0);
    float dArm = sdSegment(armP, vec2(0.05, 0.18), vec2(-0.08, -0.18)) - 0.07;

    // Double-Edged Battleaxe
    vec2 axeP = op - vec2(-0.52, 0.18);
    axeP = rot2D(0.2) * axeP;
    float dShaft = sdSegment(axeP, vec2(0.0, -0.65), vec2(0.0, 0.65)) - 0.022;
    vec2 bladeCenter = axeP - vec2(0.0, 0.32);
    float dBlade1 = sdBox2D(bladeCenter - vec2(0.18, 0.0), vec2(0.16, 0.22)) - 0.02;
    dBlade1 = max(dBlade1, -(bladeCenter.y * 1.5 + (bladeCenter.x - 0.18) * 0.8));
    float dBlade2 = sdBox2D(bladeCenter - vec2(-0.18, 0.0), vec2(0.16, 0.22)) - 0.02;
    dBlade2 = max(dBlade2, -(bladeCenter.y * 1.5 - (bladeCenter.x + 0.18) * 0.8));
    float dAxe = min(dShaft, min(dBlade1, dBlade2));

    // Combine Orc Components
    float orcArmor = min(dTorso, min(dPauldronL, dPauldronR));
    orcArmor = min(orcArmor, dHelm);
    float orcSkin = min(dNeck, min(dHead, min(dJaw, dArm)));
    float orcTotal = min(orcArmor, min(orcSkin, min(dAxe, min(dTuskL, dTuskR))));

    if (orcTotal < 0.02) {
        vec3 skinCol = vec3(0.25, 0.42, 0.18); // Orc olive skin
        vec3 armorCol = vec3(0.16, 0.15, 0.14); // Dark crude iron
        vec3 axeCol = vec3(0.46, 0.44, 0.42); // Battle steel
        vec3 tuskCol = vec3(0.88, 0.84, 0.70); // Ivory tusks

        vec3 orcPixel = skinCol;
        if (orcArmor < orcSkin && orcArmor < dAxe) {
            orcPixel = armorCol;
            float studs = sin(op.x * 50.0) * sin(op.y * 50.0);
            orcPixel += vec3(0.10) * smoothstep(0.6, 0.9, studs);
        } else if (dAxe < orcSkin && dAxe < orcArmor) {
            orcPixel = axeCol;
            float edgeDist = min(abs(dBlade1), abs(dBlade2));
            orcPixel += vec3(0.25) * fillSDF(edgeDist, 0.015);
        } else if (min(dTuskL, dTuskR) < 0.01) {
            orcPixel = tuskCol;
        }

        // Lava rim-lighting from below
        float rimLight = clamp((-op.y + 0.3) * 1.2, 0.0, 1.0);
        vec3 rimCol = vec3(1.0, 0.45, 0.10) * (1.3 * lavaFlicker);
        orcPixel += rimCol * rimLight * 0.65;

        // Glowing red/yellow eyes
        vec2 eyeL = headP - vec2(-0.05, 0.0);
        vec2 eyeR = headP - vec2(0.05, 0.0);
        float dEye = min(sdCircle(eyeL, 0.016), sdCircle(eyeR, 0.016));
        if (dEye < 0.01) {
            orcPixel = mix(vec3(1.0, 0.95, 0.2), vec3(1.0, 0.15, 0.0), clamp(dEye / 0.01, 0.0, 1.0));
        }
        float eyeGlow = exp(-dEye * 55.0);
        orcPixel += vec3(1.0, 0.3, 0.04) * eyeGlow * 1.5;

        col = mix(col, orcPixel, fillSDF(orcTotal, 0.005));
    }

    // -------------------------------------------------------------
    // 6. Flying Sparks, Embers & Ash Plumes
    // -------------------------------------------------------------
    for (float n = 0.0; n < 24.0; n += 1.0) {
        float speedMod = 0.4 + sin(n * 7.1) * 0.2;
        float sparkLife = fract(t * speedMod + n * 0.08);
        vec2 sparkPos = vec2(
            sin(n * 9.3 + t * 0.8) * 1.2 + cos(sparkLife * 4.0 + n) * 0.15,
            -0.75 + sparkLife * 1.6
        );
        float dSpark = sdCircle(p - sparkPos, 0.008 * (1.0 - sparkLife * 0.5));
        float sparkIntensity = (1.0 - sparkLife) * exp(-dSpark * 75.0);
        col += vec3(1.0, 0.65, 0.2) * sparkIntensity * 1.8;
    }

    // Soft vignette
    float vignette = clamp(1.6 - length(centered) * 0.6, 0.0, 1.0);
    col *= vignette;

    col *= intensity;
    return vec4(col, alpha);
}