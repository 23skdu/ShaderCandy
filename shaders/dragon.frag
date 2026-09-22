#include "base/common.glsl"

// dragon - The Ancient Wyrm: Hyper-detailed dragon's eye with organic cellular scales, predatory slit pupil, and internal furnace glow

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

float fillSDF(float d, float blur) {
    return 1.0 - smoothstep(-blur, blur, d);
}

// 2D Hash function for Voronoi
vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// Organic Dragon Scale Voronoi
// Returns: vec4(F1, F2 - F1, cellId.x, cellId.y)
vec4 dragonVoronoi(vec2 p) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    
    float m_dist = 8.0;
    float m_dist2 = 8.0;
    vec2 m_id = vec2(0.0);
    
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            o = 0.5 + 0.45 * sin(o * 6.2831853);
            vec2 r = g + o - f;
            float d = dot(r, r);
            
            if (d < m_dist) {
                m_dist2 = m_dist;
                m_dist = d;
                m_id = n + g;
            } else if (d < m_dist2) {
                m_dist2 = d;
            }
        }
    }
    
    float f1 = sqrt(m_dist);
    float f2 = sqrt(m_dist2);
    return vec4(f1, f2 - f1, m_id);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    vec2 p = centered;

    // -------------------------------------------------------------
    // 1. Predatory Eyelid Dynamics & Blink State
    // -------------------------------------------------------------
    float saccadeX = (sin(t * 0.6) * 0.05 + sin(t * 1.7) * 0.02);
    float saccadeY = (cos(t * 0.4) * 0.03 + cos(t * 1.3) * 0.015);
    vec2 gazeOffset = vec2(saccadeX, saccadeY);

    // Menacing blink / squint cycle
    float blinkCycle = fract(t * 0.16);
    float blink = 0.0;
    if (blinkCycle < 0.07) {
        blink = sin(blinkCycle / 0.07 * 3.14159);
    } else if (blinkCycle > 0.45 && blinkCycle < 0.65) {
        blink = 0.32 * sin((blinkCycle - 0.45) / 0.20 * 3.14159);
    }
    float lidOpen = clamp(1.0 - blink * 0.95, 0.05, 1.0);

    // Eyelid curvature equations (almond-shaped predatory aperture)
    vec2 eyeP = rot2D(-0.05) * p;
    float archTop = 0.42 * (1.0 - eyeP.x * eyeP.x * 1.35) * lidOpen;
    float archBot = -0.36 * (1.0 - eyeP.x * eyeP.x * 1.45) * lidOpen;
    float canthusLimit = 0.82; // eye width limit
    
    bool isInsideEye = (eyeP.y < archTop && eyeP.y > archBot && abs(eyeP.x) < canthusLimit);

    // Exact distance to eye opening
    float dVert = 0.0;
    if (eyeP.y >= archTop) {
        dVert = eyeP.y - archTop;
    } else if (eyeP.y <= archBot) {
        dVert = archBot - eyeP.y;
    }
    float dHoriz = max(0.0, abs(eyeP.x) - canthusLimit);
    float distToEyeLid = length(vec2(dVert, dHoriz));

    vec3 col = vec3(0.0);

    // -------------------------------------------------------------
    // 2. Dragon Eyeball (Inside the Sclera / Aperture)
    // -------------------------------------------------------------
    if (isInsideEye) {
        vec2 ip = eyeP - gazeOffset;
        float r = length(ip);
        float a = atan(ip.y, ip.x);

        // A. Sclera (Outer eye with dark amber/charcoal tone and fiery capillaries)
        float scleraDist = clamp((r - 0.42) / 0.32, 0.0, 1.0);
        vec3 scleraCol = mix(vec3(0.24, 0.16, 0.07), vec3(0.06, 0.03, 0.02), scleraDist);
        float capNoise = fbm(vec3(ip * 16.0, 2.0), 3);
        float capillary = smoothstep(0.48, 0.65, capNoise) * scleraDist;
        scleraCol = mix(scleraCol, vec3(0.85, 0.15, 0.02), capillary * 0.75);

        // B. The Dragon's Iris (Molten Solar Furnace Core)
        float irisRadius = 0.48;
        if (r < irisRadius) {
            float f1 = sin(a * 40.0 + sin(a * 8.0) * 2.5);
            float f2 = sin(a * 80.0 - cos(a * 16.0) * 2.0);
            float f3 = fbm(vec3(ip * 15.0, t * 0.15), 3);
            float striations = f1 * 0.35 + f2 * 0.25 + f3 * 0.40;

            float rings = sin(r * 68.0 - t * 1.5 + f3 * 3.0) * 0.5 + 0.5;

            // Thermal gradient:
            // Core: Blazing incandescent gold -> Solar amber -> Molten crimson -> Obsidian limbic ring
            float rNorm = r / irisRadius;
            vec3 cCore   = vec3(1.00, 0.96, 0.60); // Incandescent white-gold
            vec3 cMid1   = vec3(1.00, 0.72, 0.06); // Molten amber
            vec3 cMid2   = vec3(0.95, 0.22, 0.02); // Searing crimson
            vec3 cLimbic = vec3(0.04, 0.01, 0.00); // Black outer limbic ring

            vec3 irisCol = mix(cCore, cMid1, smoothstep(0.10, 0.42, rNorm));
            irisCol      = mix(irisCol, cMid2, smoothstep(0.42, 0.82, rNorm));
            irisCol      = mix(irisCol, cLimbic, smoothstep(0.82, 1.0, rNorm));

            irisCol *= (0.75 + 0.45 * striations + 0.15 * rings);

            // Bioluminescent internal furnace pulse
            float heatPulse = sin(t * 3.5 - r * 15.0) * 0.5 + 0.5;
            irisCol += vec3(0.4, 0.15, 0.0) * heatPulse * (1.0 - rNorm);

            scleraCol = irisCol;
        }

        // C. Razor-Sharp Vertical Slit Pupil
        float pupilW = 0.045 * (1.0 + 0.28 * sin(t * 1.8));
        float pupilH = 0.38;
        float slitDist = abs(ip.x) / pupilW + (ip.y * ip.y) / (pupilH * pupilH) - 1.0;
        
        float crenellation = sin(a * 24.0) * 0.05;
        slitDist += crenellation;

        if (slitDist < 0.0) {
            scleraCol = vec3(0.005, 0.0, 0.01);
            float innerRim = exp(-abs(slitDist) * 12.0);
            scleraCol += vec3(0.25, 0.02, 0.0) * innerRim;
        }

        // D. Corneal Wet Gloss & Double Specular Highlights
        vec2 spec1Pos = gazeOffset + vec2(0.12, 0.14);
        float dSpec1 = length(eyeP - spec1Pos);
        float spec1 = exp(-dSpec1 * 32.0);
        float spec1Aura = exp(-dSpec1 * 9.0);

        vec2 spec2Pos = gazeOffset + vec2(-0.16, -0.12);
        float dSpec2 = length(eyeP - spec2Pos);
        float spec2 = exp(-dSpec2 * 45.0) * 0.6;

        scleraCol += vec3(1.0, 0.95, 0.85) * spec1 * 1.8;
        scleraCol += vec3(1.0, 0.50, 0.15) * spec1Aura * 0.45;
        scleraCol += vec3(1.0, 0.70, 0.30) * spec2 * 1.2;

        // Shadow cast by heavy upper eyelid onto the eyeball
        float lidShadow = smoothstep(0.0, 0.18, archTop - eyeP.y);
        scleraCol *= (0.35 + 0.65 * lidShadow);

        col = scleraCol;
    }

    // -------------------------------------------------------------
    // 3. Organic Dragon Scales & Armored Brow/Cheek Plates
    // -------------------------------------------------------------
    if (!isInsideEye) {
        // Eyelid Rim (band of width 0.035 directly around the eye aperture)
        if (distToEyeLid < 0.035) {
            float rimT = distToEyeLid / 0.035;
            float rimTexture = fbm(vec3(p * 25.0, 1.0), 3);
            vec3 rimCol = mix(vec3(0.14, 0.08, 0.05), vec3(0.06, 0.04, 0.03), rimT);
            float glint = smoothstep(0.015, 0.005, abs(distToEyeLid - 0.008));
            rimCol += vec3(0.40, 0.28, 0.18) * glint;
            col = rimCol;
        } else {
            // Dragon Scale Coordinates (curving along orbital socket and brow ridge)
            vec2 scaleCoords = p;
            float radDist = length(vec2(p.x * 0.75, p.y * 1.1));
            scaleCoords += normalize(p + vec2(0.001)) * (0.08 / (radDist + 0.35));
            
            float scaleDensity = mix(9.5, 6.0, smoothstep(0.3, 0.9, radDist));
            vec4 vInfo = dragonVoronoi(scaleCoords * scaleDensity);
            
            float f1 = vInfo.x;
            float edgeDist = vInfo.y;
            vec2 cellId = vInfo.zw;
            float randVal = fract(sin(dot(cellId, vec2(12.9898, 78.233))) * 43758.5453);

            float scaleHeight = clamp(1.0 - f1 * 1.8, 0.0, 1.0);
            scaleHeight = scaleHeight * scaleHeight;

            vec3 scaleBase = mix(vec3(0.05, 0.06, 0.06), vec3(0.16, 0.13, 0.10), randVal * 0.7);
            vec3 scalePlate = mix(vec3(0.02, 0.03, 0.03), scaleBase, scaleHeight);

            // Specular highlight on scale crests
            float specPlate = pow(scaleHeight, 3.0);
            scalePlate += vec3(0.45, 0.38, 0.25) * specPlate * 0.85;

            // Magma Veins glowing in the crevices between scales
            float creviceWidth = 0.14;
            float inCrevice = 1.0 - smoothstep(0.0, creviceWidth, edgeDist);
            float magmaPulse = sin(t * 2.5 + cellId.x * 2.5 + cellId.y * 3.1) * 0.5 + 0.5;
            vec3 magmaColor = mix(vec3(1.0, 0.20, 0.02), vec3(1.0, 0.85, 0.20), magmaPulse);
            float magmaVein = inCrevice * (0.6 + 0.4 * magmaPulse);
            scalePlate += magmaColor * magmaVein * 1.8;

            // Heavy Armored Supraorbital Brow Ridge (p.y > 0.32)
            if (p.y > 0.32) {
                float browPlate = sin(p.x * 6.0 + 0.8) * 0.5 + 0.5;
                scalePlate = mix(scalePlate, vec3(0.18, 0.15, 0.12), browPlate * 0.35);
                float browShadow = smoothstep(0.55, 0.32, p.y);
                scalePlate *= (0.65 + 0.35 * (1.0 - browShadow));
            }

            // Bony Horn Spikes along Upper Brow (p.y > 0.52)
            for (float sp = -2.0; sp <= 2.0; sp += 1.0) {
                vec2 spikeBase = vec2(sp * 0.44 + 0.08, 0.56 + abs(sp) * 0.06);
                vec2 spikeTip  = spikeBase + vec2(sp * 0.26 + 0.06, 0.34 - abs(sp) * 0.04);
                float dSpike = sdSegment(p, spikeBase, spikeTip) - mix(0.060, 0.012, clamp((p.y - spikeBase.y) / 0.34, 0.0, 1.0));
                if (dSpike < 0.0) {
                    float sProgress = clamp((p.y - spikeBase.y) / 0.34, 0.0, 1.0);
                    vec3 hornCol = mix(vec3(0.12, 0.09, 0.07), vec3(0.38, 0.32, 0.22), sProgress);
                    float hornGrooves = sin(p.x * 45.0 + p.y * 30.0) * 0.5 + 0.5;
                    hornCol += vec3(0.06) * hornGrooves;
                    // Fiery magma underglow on horn underside
                    float underLight = clamp((0.6 - p.x * sp * 0.2) * (1.0 - sProgress * 0.8), 0.0, 1.0);
                    hornCol += vec3(0.7, 0.22, 0.04) * underLight * 0.7;
                    scalePlate = mix(scalePlate, hornCol, fillSDF(dSpike, 0.005));
                }
            }

            col = scalePlate;
        }

        // Occlusion shadow near the eye socket rim
        float socketShadow = smoothstep(0.18, 0.0, distToEyeLid);
        col = mix(col, col * 0.5, socketShadow);
    }

    // -------------------------------------------------------------
    // 4. Cavern Underlighting & Eye Radiance Bloom
    // -------------------------------------------------------------
    float eyeDist = length(p - gazeOffset);
    float eyeBloom = exp(-eyeDist * 3.6) * (1.0 - blink * 0.7);
    vec3 bloomCol = vec3(1.0, 0.45, 0.08);
    col += bloomCol * eyeBloom * 0.45;

    // Subterranean magma glow rising from cavern depths below
    float cavernGlow = clamp(-p.y * 0.8 + 0.15, 0.0, 1.0);
    vec3 lavaGlowCol = vec3(0.70, 0.20, 0.02) * (0.8 + 0.2 * sin(t * 2.0));
    col += lavaGlowCol * (cavernGlow * cavernGlow) * 0.55;

    // -------------------------------------------------------------
    // 5. Billowing Fiery Embers & Incandescent Sparks
    // -------------------------------------------------------------
    for (float i = 0.0; i < 24.0; i += 1.0) {
        float fi = i;
        float sparkSpeed = 0.35 + sin(fi * 5.3) * 0.15;
        float sparkLife = fract(t * sparkSpeed * 0.18 + fi * 0.09);
        
        float sway = sin(fi * 8.7 + t * 1.4) * 0.35 + cos(sparkLife * 6.28 + fi) * 0.12;
        vec2 sparkPos = vec2(
            sin(fi * 11.3) * 1.25 + sway,
            -0.75 + sparkLife * 1.6
        );

        float dSpark = length(p - sparkPos);
        float sparkSize = mix(0.016, 0.004, sparkLife);
        float sparkCore = fillSDF(dSpark - sparkSize, 0.003);
        float sparkHalo = exp(-dSpark * 40.0) * (1.0 - sparkLife);

        vec3 sparkCol = mix(vec3(1.0, 0.92, 0.35), vec3(1.0, 0.22, 0.02), sparkLife);
        col += sparkCol * (sparkCore * 1.5 + sparkHalo * 0.8);
    }

    // Atmospheric ancient wyrm vignette
    float vignette = clamp(1.45 - length(centered) * 0.45, 0.0, 1.0);
    col *= vignette;

    col = clamp(col, 0.0, 1.0) * intensity;
    return vec4(col, alpha);
}