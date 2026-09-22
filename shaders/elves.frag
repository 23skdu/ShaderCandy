#include "base/common.glsl"

// elves - Lothlorien starlight sanctuary with silver Mallorn trees, celestial moonlit waterfall, and noble elven ranger

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

float sdUnevenCapsule(vec2 p, float r1, float r2, float h) {
    p.x = abs(p.x);
    float b = (r1 - r2) / h;
    float a = sqrt(max(0.0, 1.0 - b * b));
    float k = dot(p, vec2(-b, a));
    if (k < 0.0) return length(p) - r1;
    if (k > a * h) return length(p - vec2(0.0, h)) - r2;
    return dot(p, vec2(a, b)) - r1;
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

    // -------------------------------------------------------------
    // 1. Deep Midnight Twilight Sky & Lothlorien Moon
    // -------------------------------------------------------------
    vec3 skyZenith = vec3(0.012, 0.025, 0.08); // Midnight sapphire
    vec3 skyMid    = vec3(0.025, 0.08, 0.13);  // Deep twilight teal
    vec3 skyMist   = vec3(0.06, 0.17, 0.20);   // Ethereal silver-teal mist
    
    float skyT = clamp((p.y + 0.3) * 0.7, 0.0, 1.0);
    vec3 col = mix(skyMist, mix(skyMid, skyZenith, smoothstep(0.2, 0.9, skyT)), skyT);

    // Subtle twinkling stars in gaps
    vec2 starGrid = p * 16.0;
    vec2 starCell = floor(starGrid);
    vec2 starFrac = fract(starGrid) - 0.5;
    float starRand = fract(sin(dot(starCell, vec2(127.1, 311.7))) * 43758.5453);
    if (starRand > 0.86 && p.y > -0.1) {
        float twinkle = sin(t * 3.0 + starRand * 18.0) * 0.45 + 0.55;
        float dStar = length(starFrac) - (0.04 + starRand * 0.04);
        col += vec3(0.75, 0.92, 1.0) * (1.0 - smoothstep(0.0, 0.08, dStar)) * twinkle * clamp((p.y + 0.1) * 1.5, 0.0, 1.0);
    }

    // Radiant Lothlorien Full Moon
    vec2 moonPos = vec2(0.18, 0.52);
    float dMoon = sdCircle(p - moonPos, 0.18);
    float moonHaloOuter = exp(-max(0.0, dMoon) * 3.2);
    float moonHaloInner = exp(-max(0.0, dMoon) * 8.5);
    col += vec3(0.45, 0.78, 0.95) * moonHaloOuter * 0.45;
    col += vec3(0.85, 0.95, 1.0) * moonHaloInner * 0.70;
    
    // Moon disc with delicate lunar texture
    if (dMoon < 0.0) {
        float craterNoise = fbm(vec3((p - moonPos) * 7.0, 1.2), 2);
        vec3 moonDiscCol = mix(vec3(0.97, 0.99, 1.0), vec3(0.80, 0.88, 0.95), craterNoise * 0.35);
        col = mix(col, moonDiscCol, fillSDF(dMoon, 0.005));
    }

    // Volumetric Moonbeams (God Rays)
    vec2 rayCoord = rot2D(0.28) * (p - moonPos);
    float r1 = sin(rayCoord.x * 8.0 + t * 0.20) * 0.5 + 0.5;
    float r2 = sin(rayCoord.x * 19.0 - t * 0.15) * 0.5 + 0.5;
    float rays = r1 * r2;
    float rayBeamMask = smoothstep(0.8, -0.6, p.y) * exp(-abs(p.x - moonPos.x) * 1.6);
    col += vec3(0.30, 0.65, 0.75) * rays * rayBeamMask * 0.32;

    // Distant Elven Sanctuaries / Spires (Caras Galadhon / Rivendell)
    for (float sp = -2.0; sp <= 2.0; sp += 1.0) {
        if (abs(sp) < 0.1) continue;
        float sx = sp * 0.48 - 0.25 + sin(sp * 4.2) * 0.08;
        float sw = 0.022;
        float sh = 0.35 + cos(sp * 3.1) * 0.12;
        float spireD = abs(p.x - sx) - sw * max(0.06, (sh - p.y) / max(0.1, sh));
        if (p.y < sh && p.y > -0.25 && spireD < 0.0) {
            vec3 spCol = mix(vec3(0.04, 0.12, 0.15), vec3(0.16, 0.32, 0.36), clamp((p.y + 0.2) / sh, 0.0, 1.0));
            float lanternDist = length(p - vec2(sx, sh));
            spCol += vec3(0.65, 0.92, 1.0) * exp(-lanternDist * 28.0);
            col = mix(col, spCol, fillSDF(spireD, 0.004));
        }
    }

    // -------------------------------------------------------------
    // 2. Cascading Waterfall & Natural Mountain Ledge (Left Sanctuary)
    // -------------------------------------------------------------
    // Natural continuous mountain slope rising high into the canopy
    float mountainSlope = -0.36 - (p.y + 0.3) * 0.25 + sin(p.y * 3.5) * 0.04;
    if (p.x < mountainSlope) {
        vec3 rockCol = mix(vec3(0.03, 0.08, 0.07), vec3(0.08, 0.18, 0.16), clamp((p.y + 0.4) * 0.8, 0.0, 1.0));
        float rockNoise = noise(p * 8.0);
        rockCol += vec3(0.02, 0.06, 0.04) * rockNoise;
        float rockRim = smoothstep(0.05, 0.0, mountainSlope - p.x);
        rockCol += vec3(0.20, 0.50, 0.55) * rockRim * 0.5;
        col = mix(col, rockCol, fillSDF(p.x - mountainSlope, 0.008));
    }

    // Cascading Moonlit Waterfall pouring into the lake
    float wfX = -0.56 + sin(p.y * 5.0) * 0.02;
    float wfWidth = 0.06 - p.y * 0.015;
    float dWaterfall = abs(p.x - wfX) - wfWidth;
    if (p.y > -0.44 && dWaterfall < 0.0) {
        float wfStream = sin(p.y * 36.0 - t * 14.0) * 0.5 + 0.5;
        float wfFlow2  = cos(p.y * 50.0 - t * 20.0 + p.x * 12.0) * 0.5 + 0.5;
        vec3 wfCol = mix(vec3(0.18, 0.46, 0.58), vec3(0.85, 0.95, 1.0), wfStream * 0.7 + wfFlow2 * 0.3);
        wfCol += vec3(0.25) * smoothstep(0.7, 0.98, wfStream);
        col = mix(col, wfCol, fillSDF(dWaterfall, 0.006));
    }
    // Waterfall spray mist
    vec2 sprayPos = vec2(-0.56, -0.42);
    float dSpray = length(p - sprayPos);
    col += vec3(0.35, 0.70, 0.80) * exp(-dSpray * 5.5) * 0.35;

    // -------------------------------------------------------------
    // 3. Sacred Mirror Lake & Moonlit Reflections
    // -------------------------------------------------------------
    float waterY = -0.42;
    if (p.y < waterY) {
        float depth = clamp((waterY - p.y) / 0.45, 0.0, 1.0);
        vec3 deepWater = vec3(0.015, 0.04, 0.06);
        vec3 surfaceWater = vec3(0.035, 0.11, 0.15);
        vec3 waterCol = mix(surfaceWater, deepWater, depth);

        // Wavelet ripple reflections
        float wave1 = sin(p.x * 14.0 + (p.y - waterY) * 50.0 + t * 2.5);
        float wave2 = cos(p.x * 28.0 - (p.y - waterY) * 35.0 - t * 1.8);
        float waves = smoothstep(0.2, 0.85, wave1 * 0.5 + wave2 * 0.5);

        // Moon shimmer reflection
        float moonReflX = abs(p.x - moonPos.x);
        float moonShimmer = exp(-moonReflX * 6.0) * (0.4 + 0.6 * waves);
        vec3 moonReflCol = vec3(0.65, 0.88, 1.0);
        waterCol += moonReflCol * moonShimmer * (1.0 - depth * 0.65);

        // Waterfall pool turbulence ripples
        float poolDist = length(vec2((p.x - wfX) * 1.5, p.y - waterY));
        float poolRipple = sin(poolDist * 32.0 - t * 6.0) * exp(-poolDist * 4.5);
        waterCol += vec3(0.3, 0.65, 0.8) * max(0.0, poolRipple) * 0.5;

        col = mix(col, waterCol, fillSDF(waterY - p.y, 0.008));

        // Sacred floating water lilies (Niphredil blossoms)
        for (float ly = 0.0; ly < 4.0; ly += 1.0) {
            vec2 lilyP = vec2(-0.80 + ly * 0.46 + sin(ly * 3.7) * 0.12, waterY - 0.07 - ly * 0.06);
            float dPad = length((p - lilyP) * vec2(1.0, 2.4)) - 0.042;
            if (dPad < 0.0) {
                col = mix(col, vec3(0.03, 0.15, 0.08), fillSDF(dPad, 0.003));
            }
            float dPetal = length(p - (lilyP + vec2(0.0, 0.012))) - 0.014;
            float lilyAura = exp(-dPetal * 30.0);
            col += vec3(0.5, 0.95, 0.8) * lilyAura * 0.45;
            col = mix(col, vec3(0.92, 0.98, 0.95), fillSDF(dPetal, 0.003));
        }
    }

    // Natural mossy bank rising smoothly on the right
    float bankY = mix(-0.52, -0.32, smoothstep(-0.35, 0.35, p.x)) + sin(p.x * 3.5) * 0.02;
    if (p.y < bankY && p.x > -0.35) {
        float mossN = noise(p * 9.0);
        vec3 hillCol = mix(vec3(0.03, 0.07, 0.05), vec3(0.07, 0.16, 0.09), mossN);
        float hillRim = smoothstep(0.03, 0.0, bankY - p.y);
        hillCol += vec3(0.20, 0.50, 0.40) * hillRim * 0.5;
        col = mix(col, hillCol, fillSDF(p.y - bankY, 0.005));
    }

    // -------------------------------------------------------------
    // 4. Majestic Silver Mallorn Trees & Starlight Canopy
    // -------------------------------------------------------------
    // Slender graceful Left Mallorn Tree Trunk
    vec2 trunkLP = p - vec2(-1.26, 0.0);
    float swayL = sin(p.y * 1.5) * 0.04;
    float widthL = 0.16 - p.y * 0.04;
    float dTrunkL = abs(trunkLP.x - swayL) - widthL;

    // Slender graceful Right Mallorn Tree Trunk
    vec2 trunkRP = p - vec2(1.34, 0.0);
    float swayR = -sin(p.y * 1.5) * 0.04;
    float widthR = 0.16 - p.y * 0.04;
    float dTrunkR = abs(trunkRP.x - swayR) - widthR;

    float dTrunks = min(dTrunkL, dTrunkR);
    if (dTrunks < 0.02) {
        float barkPattern = noise(vec2(p.x * 12.0, p.y * 30.0));
        vec3 barkCol = mix(vec3(0.08, 0.16, 0.16), vec3(0.20, 0.30, 0.30), barkPattern);
        barkCol += vec3(0.25, 0.55, 0.65) * 0.35;
        col = mix(col, barkCol, fillSDF(dTrunks, 0.005));
    }

    // Lush Golden-Green Mallorn Canopy above
    float canopyY = 0.60 + sin(p.x * 2.2) * 0.06 + cos(p.x * 4.5) * 0.03;
    float canopyNoise = fbm(vec3(p.xy * 3.5, t * 0.04), 3);
    canopyY += canopyNoise * 0.12;
    if (p.y > canopyY - 0.22) {
        float fDepth = clamp((p.y - (canopyY - 0.22)) / 0.32, 0.0, 1.0);
        vec3 fCol = mix(vec3(0.04, 0.18, 0.12), vec3(0.12, 0.38, 0.24), fDepth);
        fCol = mix(fCol, vec3(0.78, 0.72, 0.32), smoothstep(0.4, 0.8, canopyNoise) * 0.42);
        col = mix(col, fCol, fillSDF(canopyY - p.y, 0.015));
    }

    // Suspended Elven Crystal Lanterns
    for (float la = -1.0; la <= 1.0; la += 2.0) {
        vec2 lantP = vec2(la * 0.65, 0.44 + la * 0.05);
        float dCord = sdSegment(p, lantP + vec2(0.0, 0.20), lantP) - 0.003;
        col = mix(col, vec3(0.3, 0.5, 0.5), fillSDF(dCord, 0.002));
        
        float dLant = sdCircle(p - lantP, 0.022);
        float lantGlow = exp(-length(p - lantP) * 16.0);
        col += vec3(0.35, 0.85, 1.0) * lantGlow * 0.8;
        col = mix(col, vec3(0.9, 0.98, 1.0), fillSDF(dLant, 0.003));
    }

    // -------------------------------------------------------------
    // 5. Noble Elven Ranger / Archer (Sculpted Silhouette & Glow)
    // -------------------------------------------------------------
    vec2 archerOrigin = vec2(0.36, -0.16);
    vec2 ap = p - archerOrigin;

    // A. Flowing hooded cloak & elven tunic
    float dCloak = sdUnevenCapsule(vec2(ap.x - 0.03, -(ap.y - 0.02)), 0.11, 0.18, 0.38);
    float dTorso = sdUnevenCapsule(vec2(ap.x, -(ap.y - 0.22)), 0.07, 0.05, 0.20);
    
    // B. Head, Hood Cowl, Face Profile & Pointed Ear
    vec2 headP = ap - vec2(0.0, 0.25);
    vec2 cowlP = headP - vec2(0.04, 0.02);
    float dHood = sdUnevenCapsule(vec2(-cowlP.x, cowlP.y), 0.065, 0.01, 0.11);
    
    vec2 faceP = headP - vec2(-0.032, -0.012);
    float dFace = sdCircle(faceP, 0.034);
    
    vec2 earP = headP - vec2(0.01, 0.015);
    earP = rot2D(-0.45) * earP;
    float dEar = sdUnevenCapsule(earP, 0.014, 0.0025, 0.062);

    // C. Flowing golden/platinum hair cascading down back
    vec2 hairP = ap - vec2(0.07, 0.10);
    float hairWave = sin(hairP.y * 12.0 - t * 2.0) * 0.016;
    float dHair = sdSegment(vec2(hairP.x + hairWave, hairP.y), vec2(-0.02, 0.12), vec2(0.06, -0.18)) - 0.030;

    // D. Arms & Archer Stance
    vec2 armL_start = vec2(-0.02, 0.12);
    vec2 armL_end   = vec2(-0.20, 0.08);
    float dArmBow = sdSegment(ap, armL_start, armL_end) - 0.018;

    vec2 armR_shoulder = vec2(0.04, 0.12);
    vec2 armR_elbow    = vec2(0.14, 0.10);
    vec2 armR_hand     = vec2(0.02, 0.15); // near cheek
    float dArmDraw = min(sdSegment(ap, armR_shoulder, armR_elbow), sdSegment(ap, armR_elbow, armR_hand)) - 0.017;

    // E. Quiver on back with arrows
    vec2 quiverP = rot2D(0.42) * (ap - vec2(0.08, 0.08));
    float dQuiver = sdBox2D(quiverP, vec2(0.024, 0.14)) - 0.008;
    vec2 fletchP = quiverP - vec2(0.0, 0.16);
    float dFletch = sdSegment(fletchP, vec2(-0.02, 0.0), vec2(0.02, 0.04)) - 0.010;

    // F. Masterwork Lothlorien Recurve Bow
    vec2 bp = ap - vec2(-0.20, 0.08);
    float bowCurveX = -0.05 * cos(bp.y * 7.5);
    float dBow = max(abs(bp.x - bowCurveX) - 0.012, abs(bp.y) - 0.38);
    vec2 tipT = bp - vec2(-0.05 * cos(0.38 * 7.5), 0.38);
    vec2 tipB = bp - vec2(-0.05 * cos(-0.38 * 7.5), -0.38);
    dBow = min(dBow, min(length(tipT), length(tipB)) - 0.015);

    // G. Drawn Bowstring from tips to draw hand
    vec2 bowTipTop = vec2(-0.20 - 0.05 * cos(0.38 * 7.5), 0.08 + 0.38);
    vec2 bowTipBot = vec2(-0.20 - 0.05 * cos(-0.38 * 7.5), 0.08 - 0.38);
    vec2 drawHandPos = armR_hand;
    float dString = min(
        sdSegment(ap, bowTipTop, drawHandPos),
        sdSegment(ap, bowTipBot, drawHandPos)
    ) - 0.003;

    // H. Luminous Starlight Arrow
    vec2 arrowTipPos = vec2(-0.38, 0.09);
    float dArrow = sdSegment(ap, drawHandPos, arrowTipPos) - 0.005;

    // Combine Character Parts
    float elfBody = min(min(min(dCloak, dTorso), min(dHood, dFace)),
                        min(min(dArmBow, dArmDraw), min(dEar, min(dQuiver, dFletch))));
    float elfTotal = min(elfBody, min(dHair, min(dBow, min(dArrow, dString))));

    if (elfTotal < 0.02) {
        // Deep woodland green cloak & hood
        vec3 elfPixel = vec3(0.05, 0.14, 0.09);

        if (dFace < 0.0) {
            // Fair elven countenance
            elfPixel = vec3(0.85, 0.77, 0.72);
        } else if (dEar < 0.0) {
            // Pointed ear
            elfPixel = vec3(0.86, 0.75, 0.70);
        } else if (dHair < elfBody && dHair < dBow) {
            // Flowing golden-blonde / platinum hair
            elfPixel = mix(vec3(0.92, 0.85, 0.58), vec3(0.98, 0.95, 0.80), sin(hairP.y * 22.0) * 0.5 + 0.5);
        } else if (dBow < elfBody) {
            // Polished Mallorn wood inlaid with pure silver filigree
            elfPixel = mix(vec3(0.32, 0.25, 0.16), vec3(0.75, 0.85, 0.90), sin(bp.y * 25.0) * 0.5 + 0.5);
        } else if (dQuiver < elfBody || dFletch < elfBody) {
            // Silver-embroidered leather quiver
            elfPixel = vec3(0.18, 0.24, 0.22);
        } else if (dString < elfBody || dArrow < elfBody) {
            // Celestial starlight arrow & string
            elfPixel = vec3(0.95, 0.99, 1.0);
        }

        // Moonlight rim lighting along the back profile
        float rimFactor = clamp((ap.x * 1.5 + ap.y * 0.3 + 0.2), 0.0, 1.0);
        vec3 rimCol = vec3(0.40, 0.75, 0.90);
        elfPixel += rimCol * (rimFactor * rimFactor) * 0.40;

        col = mix(col, elfPixel, fillSDF(elfTotal, 0.004));
    }

    // Radiant Starlight Arrowhead Flare
    vec2 worldArrowTip = archerOrigin + arrowTipPos;
    float dArrowTip = length(p - worldArrowTip);
    float tipGlow = exp(-dArrowTip * 28.0);
    float tipAura = exp(-dArrowTip * 7.5);
    col += vec3(0.5, 0.92, 1.0) * tipGlow * 2.2;
    col += vec3(0.2, 0.65, 0.9) * tipAura * 0.75;

    // Cross flare on starlight arrow tip
    vec2 flareP = p - worldArrowTip;
    float crossFlare = exp(-abs(flareP.x) * 40.0) * exp(-abs(flareP.y) * 4.0)
                     + exp(-abs(flareP.y) * 40.0) * exp(-abs(flareP.x) * 4.0);
    col += vec3(0.85, 0.98, 1.0) * crossFlare * 0.55;

    // -------------------------------------------------------------
    // 6. Ethereal Willowisps & Drifting Golden Mallorn Leaves
    // -------------------------------------------------------------
    // Luminous Will-o'-the-wisps dancing through the twilight glade
    for (float w = 0.0; w < 6.0; w += 1.0) {
        float wSpeed = 0.20 + sin(w * 2.5) * 0.08;
        vec2 wispP = vec2(
            sin(t * wSpeed + w * 1.6) * 1.0 - 0.15,
            -0.20 + cos(t * (wSpeed * 0.75) + w * 2.0) * 0.26
        );
        float dW = length(p - wispP);
        float wispCore = exp(-dW * 26.0);
        float wispHalo = exp(-dW * 6.5);
        vec3 wCol = mix(vec3(0.25, 0.95, 0.80), vec3(0.48, 0.82, 1.0), sin(w + t * 0.6) * 0.5 + 0.5);
        col += wCol * (wispCore * 1.3 + wispHalo * 0.4);
    }

    // Drifting golden elanor / mallorn leaves
    for (float lf = 0.0; lf < 14.0; lf += 1.0) {
        float lfSpeed = 0.16 + sin(lf * 2.8) * 0.07;
        float lfCycle = fract(t * lfSpeed * 0.12 + lf * 0.17);
        vec2 leafP = vec2(
            sin(lf * 8.5 + t * 0.3) * 1.2 + sin(lfCycle * 6.28) * 0.16,
            0.65 - lfCycle * 1.3
        );
        float dLeaf = length((p - leafP) * vec2(1.0, 1.8)) - 0.013;
        if (dLeaf < 0.01) {
            float leafGlow = exp(-max(0.0, dLeaf) * 45.0);
            vec3 lfCol = mix(vec3(0.85, 0.75, 0.25), vec3(1.0, 0.92, 0.55), sin(lf + t) * 0.5 + 0.5);
            col = mix(col, lfCol, fillSDF(dLeaf, 0.003));
            col += lfCol * leafGlow * 0.30;
        }
    }

    // Ethereal subtle sanctuary vignette
    float vignette = clamp(1.48 - length(centered) * 0.42, 0.0, 1.0);
    col *= vignette;

    col = clamp(col, 0.0, 1.0) * intensity;
    return vec4(col, alpha);
}