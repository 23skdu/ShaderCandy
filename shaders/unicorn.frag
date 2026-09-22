#include "base/common.glsl"

// unicorn - Majestic celestial unicorn under twilight starlight and radiant alicorn flare

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

float fillSDF(float d, float blur) {
    return 1.0 - smoothstep(-blur, blur, d);
}

vec3 rainbowColor(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    vec2 p = centered;

    // -------------------------------------------------------------
    // 1. Celestial Twilight Sky & Glowing Nebula
    // -------------------------------------------------------------
    vec3 skyTop = vec3(0.04, 0.02, 0.12);
    vec3 skyMid = vec3(0.10, 0.04, 0.22);
    vec3 skyBot = vec3(0.18, 0.08, 0.28);
    vec3 col = mix(skyBot, skyTop, clamp((p.y + 0.8) * 0.6, 0.0, 1.0));

    // Cosmic nebula clouds
    vec2 nebUV = p * 0.8 + vec2(t * 0.03, t * 0.015);
    float neb1 = fbm(vec3(nebUV * 2.0, t * 0.05), 3);
    float neb2 = fbm(vec3(nebUV * 3.5 + 2.0, t * 0.08), 3);
    col += vec3(0.22, 0.08, 0.35) * smoothstep(0.15, 0.75, neb1);
    col += vec3(0.08, 0.18, 0.32) * smoothstep(0.25, 0.85, neb2);

    // Crescent Moon in top left
    vec2 moonPos = vec2(-1.15, 0.58);
    float dMoon1 = sdCircle(p - moonPos, 0.22);
    float dMoon2 = sdCircle(p - (moonPos + vec2(0.07, 0.05)), 0.21);
    float moonCrescent = max(dMoon1, -dMoon2);
    float moonGlow = exp(-dMoon1 * 8.0);
    col += vec3(0.95, 0.92, 1.0) * moonGlow * 0.45;
    col = mix(col, vec3(1.0, 0.98, 0.92), fillSDF(moonCrescent, 0.006));

    // Twinkling Celestial Stars (organically scattered)
    vec2 starCell = floor(p * 12.0);
    vec2 starJitter = (hash2(starCell) - 0.5) * 0.8;
    vec2 starUV = fract(p * 12.0) - 0.5 - starJitter;
    float starRand = hash(starCell);
    if (starRand > 0.58) {
        float twinkle = 0.5 + 0.5 * sin(t * (2.5 + starRand * 5.0) + starRand * 20.0);
        float starDist = length(starUV);
        float starFlare = max(0.0, 1.0 - starDist * (10.0 - twinkle * 4.0));
        vec3 starCol = mix(vec3(0.7, 0.9, 1.0), vec3(1.0, 0.8, 0.9), starRand);
        col += starCol * starFlare * twinkle * 0.9;
    }

    // -------------------------------------------------------------
    // 2. Enchanted Meadow Foreground
    // -------------------------------------------------------------
    float hillY = -0.68 + sin(p.x * 2.0) * 0.06 + cos(p.x * 4.5) * 0.02;
    if (p.y < hillY) {
        float hillDepth = clamp((hillY - p.y) / 0.15, 0.0, 1.0);
        vec3 grassCol = mix(vec3(0.06, 0.04, 0.12), vec3(0.03, 0.02, 0.07), hillDepth);
        col = mix(col, grassCol, fillSDF(p.y - hillY, 0.005));
    }

    // -------------------------------------------------------------
    // 3. Graceful Equine Unicorn Head & Arched Neck
    // -------------------------------------------------------------
    vec2 uPos = vec2(0.12, -0.22);
    vec2 up = p - uPos;

    // Muscular Arched Neck extending down past bottom
    vec2 neckP = up - vec2(-0.25, -0.48);
    neckP = rot2D(-0.42) * neckP;
    float dNeck = sdUnevenCapsule(neckP, 0.44, 0.22, 1.10);

    // Equine Jaw & Cheek
    vec2 cheekP = up - vec2(-0.06, 0.12);
    float dCheek = sdCircle(cheekP, 0.22);

    // Tapered Muzzle / Snout
    vec2 muzzleP = up - vec2(0.24, 0.08);
    muzzleP = rot2D(0.35) * muzzleP;
    float dMuzzle = sdUnevenCapsule(muzzleP, 0.16, 0.09, 0.28);

    // Nostril
    vec2 nostrilP = up - vec2(0.42, 0.02);
    float dNostril = sdCircle(nostrilP, 0.022);

    // Graceful Upright Ear
    vec2 earP = up - vec2(-0.16, 0.44);
    earP = rot2D(0.26) * earP;
    float dEar = sdUnevenCapsule(earP, 0.065, 0.012, 0.26);

    // Forelock mane wisps over forehead
    vec2 foreP = up - vec2(-0.02, 0.36);
    float dForelock = sdSegment(foreP, vec2(0.0, 0.0), vec2(0.14, -0.14)) - 0.035;

    // Combine Head & Body
    float uniBody = min(dNeck, min(dCheek, min(dMuzzle, min(dEar, dForelock))));



    // -------------------------------------------------------------
    // 4. Radiant Crystalline Alicorn (Spiral Horn)
    // -------------------------------------------------------------
    vec2 hornBase = up - vec2(0.04, 0.32);
    hornBase = rot2D(-0.62) * hornBase;
    float hornLen = 0.78;
    float dHorn = sdUnevenCapsule(hornBase, 0.042, 0.006, hornLen);

    // Tip of horn in world space
    vec2 hornTipWorld = uPos + vec2(0.04, 0.32) + rot2D(0.62) * vec2(0.0, hornLen);

    // -------------------------------------------------------------
    // 5. Silky Flowing Prismatic Rainbow Mane
    // -------------------------------------------------------------
    float maneDist = 1e5;
    vec3 maneColorSum = vec3(0.0);
    float maneWeightSum = 0.0;

    for (float m = 0.0; m < 7.0; m += 1.0) {
        float mf = m / 6.0;
        float strandPhase = t * 2.8 + m * 0.7;
        float yStart = 0.45 - m * 0.11;
        float xStart = -0.15 - m * 0.08;
        
        // Sinuous bezier-like wave for mane strands
        vec2 mPos = up - vec2(xStart, yStart);
        float wave = sin(mPos.y * 7.0 - strandPhase) * (0.05 + m * 0.012);
        wave += cos(mPos.y * 14.0 + strandPhase * 0.7) * 0.02;
        
        vec2 strandVec = vec2(mPos.x + wave + mPos.y * 0.5, mPos.y);
        float strandD = sdSegment(strandVec, vec2(0.0, 0.0), vec2(-0.45 - m * 0.06, -0.35)) - (0.028 + m * 0.004);
        
        if (strandD < maneDist) {
            maneDist = strandD;
        }
        
        float w = smoothstep(0.04, -0.01, strandD);
        if (w > 0.001) {
            vec3 strandCol = rainbowColor(mf + t * 0.12);
            maneColorSum += strandCol * w;
            maneWeightSum += w;
        }
    }

    vec3 finalManeCol = (maneWeightSum > 0.0) ? (maneColorSum / maneWeightSum) : vec3(1.0);

    // -------------------------------------------------------------
    // Shading Unicorn Silhouette & Surface
    // -------------------------------------------------------------
    if (uniBody < 0.04) {
        // Alabaster white coat with gentle lavender/cyan iridescence
        vec3 coatCol = vec3(0.95, 0.95, 1.0);
        float coatShade = clamp((up.y + 0.4) * 0.9, 0.0, 1.0);
        coatCol = mix(vec3(0.80, 0.78, 0.92), coatCol, coatShade);

        // Soft lunar rim light from top-left
        float rimLight = clamp((-up.x * 0.7 + up.y * 0.8 + 0.3), 0.0, 1.0);
        coatCol += vec3(0.20, 0.28, 0.45) * pow(rimLight, 2.0);

        // Soft pink blush on muzzle and ear inner
        float blushMuzzle = exp(-sdCircle(up - vec2(0.35, 0.02), 0.12) * 15.0);
        coatCol = mix(coatCol, vec3(0.98, 0.84, 0.88), clamp(blushMuzzle * 0.45, 0.0, 1.0));

        // Nostril indent
        coatCol = mix(coatCol, vec3(0.45, 0.35, 0.45), fillSDF(dNostril, 0.008));

        // Intelligent Dark Equine Eye with Starlight Glint
        vec2 eyeP = up - vec2(0.10, 0.20);
        float dEye = sdCircle(eyeP, 0.038);
        float dIris = sdCircle(eyeP, 0.026);
        float dPupil = sdCircle(eyeP, 0.016);
        float dGlint = sdCircle(eyeP - vec2(-0.009, 0.010), 0.007);
        float dGlint2 = sdCircle(eyeP - vec2(0.008, -0.007), 0.004);

        if (dEye < 0.02) {
            coatCol = mix(coatCol, vec3(0.12, 0.08, 0.18), fillSDF(dEye, 0.004));
            coatCol = mix(coatCol, vec3(0.48, 0.32, 0.72), fillSDF(dIris, 0.003));
            coatCol = mix(coatCol, vec3(0.05, 0.02, 0.08), fillSDF(dPupil, 0.003));
            coatCol = mix(coatCol, vec3(1.0, 1.0, 1.0), fillSDF(dGlint, 0.002));
            coatCol = mix(coatCol, vec3(1.0, 1.0, 1.0), fillSDF(dGlint2, 0.002));
        }

        col = mix(col, coatCol, fillSDF(uniBody, 0.004));
    }

    // Shading Mane
    if (maneDist < 0.02) {
        vec3 mCol = finalManeCol * 1.15;
        // Silk shine highlight
        float shine = sin(up.y * 35.0 - t * 4.0) * 0.5 + 0.5;
        mCol += vec3(0.25) * pow(shine, 3.0);
        col = mix(col, mCol, fillSDF(maneDist, 0.005));
    }

    // Shading Crystalline Alicorn
    if (dHorn < 0.03) {
        // Helical spiral facets
        float spiral = sin(hornBase.y * 45.0 - t * 4.0) * 0.5 + 0.5;
        vec3 hornCol = mix(vec3(0.85, 0.92, 1.0), vec3(1.0, 0.85, 0.98), spiral);
        hornCol += vec3(0.35) * pow(spiral, 4.0); // Specular diamond sheen
        col = mix(col, hornCol, fillSDF(dHorn, 0.003));
    }

    // -------------------------------------------------------------
    // 6. Radiant Starburst Flare & Volumetric Corona at Horn Tip
    // -------------------------------------------------------------
    vec2 tipVec = p - hornTipWorld;
    float dTip = length(tipVec);
    
    // Core brilliant starburst
    float tipGlow = exp(-dTip * 16.0);
    float tipAura = exp(-dTip * 4.5);
    
    // Rotating prismatic starburst diffraction spikes
    float angle = atan(tipVec.y, tipVec.x) + t * 0.4;
    float spikes = pow(max(0.0, cos(angle * 4.0)), 12.0) * 0.8;
    spikes += pow(max(0.0, cos(angle * 8.0 + 0.8)), 16.0) * 0.4;
    
    vec3 flareCol = mix(vec3(1.0, 0.95, 0.90), vec3(0.70, 0.85, 1.0), sin(t * 2.0) * 0.5 + 0.5);
    col += flareCol * (tipGlow * 2.2 + tipAura * 0.7 + spikes * exp(-dTip * 6.0) * 1.5);

    // -------------------------------------------------------------
    // 7. Drifting Magic Fireflies & Sparkles
    // -------------------------------------------------------------
    for (float k = 0.0; k < 28.0; k += 1.0) {
        float kSpeed = 0.35 + sin(k * 4.3) * 0.15;
        float kLife = fract(t * kSpeed * 0.2 + k * 0.07);
        vec2 sparkPos = vec2(
            sin(k * 7.1 + t * 0.6) * 1.4 + cos(kLife * 3.0 + k) * 0.2,
            -0.75 + kLife * 1.6 + sin(k * 3.7) * 0.2
        );
        float dSpark = length(p - sparkPos);
        float sparkleSize = 0.007 * (1.0 - kLife * 0.4);
        float sparkle = exp(-dSpark * 90.0) * (0.6 + 0.4 * sin(t * 6.0 + k * 2.0));
        vec3 moteCol = rainbowColor(k * 0.15 + t * 0.05);
        col += moteCol * sparkle * 1.6;
    }

    // Soft celestial vignette
    float vignette = clamp(1.5 - length(centered) * 0.45, 0.0, 1.0);
    col *= vignette;

    col = clamp(col, 0.0, 1.0) * intensity;
    return vec4(col, alpha);
}