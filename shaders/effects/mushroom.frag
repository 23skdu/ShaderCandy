#version 450 core

#include "base/common.glsl"

// Mushroom - 3D rotating neon mushrooms on fractal background

// Mushroom SDF
float sdMushroom(vec3 p, float t) {
    // Cap (sphere-like)
    float cap = length(p - vec3(0.0, 0.3, 0.0)) - 0.4;
    
    // Stalk (cylinder-like)
    float stalk = length(vec2(p.x, p.z)) - 0.12;
    stalk = max(stalk, abs(p.y + 0.1) - 0.4);
    
    // Combine
    return min(cap, stalk);
}

// Per-mushroom state that depends only on the uniform time value.
//
// map() is called ~70 times per pixel (64 march steps + 6 for the normal), and
// the original code recomputed three sin/cos plus a rotation matrix per
// mushroom inside every one of those calls. All of it is loop-invariant with
// respect to the sample point and cannot change within a frame, so it is
// computed once per fragment here instead. Measured +17% (see
// docs/experiments.md E2).
vec3 mPos[8];
mat2 mRot[8];
float mScale[8];

void setupMushrooms(float t) {
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        mPos[i] = vec3(
            sin(fi * 1.3 + t * 0.5) * 1.5,
            sin(fi * 0.7 + t * 0.3) * 0.3,
            cos(fi * 1.1 + t * 0.4) * 1.5
        );
        mRot[i] = rot(t * (0.5 + fi * 0.1) + fi);
        mScale[i] = 0.3 + fi * 0.05;
    }
}

// Scene SDF
float map(vec3 p, float t) {
    float d = 100.0;

    // Multiple mushrooms as particles
    for (int i = 0; i < 8; i++) {
        // Individual mushroom
        vec3 q = p - mPos[i];

        // Rotate on X axis
        q.yz *= mRot[i];

        // Scale varies
        float s = mScale[i];
        q /= s;

        float mushroom = sdMushroom(q, t) * s;
        d = min(d, mushroom);
    }

    return d;
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, float t) {
    float dO = 0.0;
    
    for(int i = 0; i < 64; i++) {
        vec3 p = ro + rd * dO;
        float dS = map(p, t);
        
        dO += dS;
        if(dO > 20.0 || dS < 0.001) break;
    }
    
    return dO;
}

// Normal calculation
vec3 calcNormal(vec3 p, float t) {
    vec2 e = vec2(0.001, 0.0);
    // 4-tap tetrahedral normal: 4 field evaluations instead of the
    // 6 that central differencing needs.
    const vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * map(p + k.xyy * e.x, t) +
        k.yyx * map(p + k.yyx * e.x, t) +
        k.yxy * map(p + k.yxy * e.x, t) +
        k.xxx * map(p + k.xxx * e.x, t));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;

    setupMushrooms(t);

    // Camera
    vec3 ro = vec3(cos(t * 0.3) * 3.0, 0.5 + sin(t * 0.2) * 0.3, sin(t * 0.3) * 3.0);
    vec3 ta = vec3(0.0, 0.0, 0.0);
    
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Background - fractal neon
    vec3 col = vec3(0.0);
    float bg = fbm(vec3(uv * 5.0, t * 0.1), 4);
    col = vec3(0.1, 0.0, 0.2) * bg;
    col += vec3(0.0, 0.3, 0.5) * (1.0 - bg) * 0.5;
    
    // Ray march
    float d = rayMarch(ro, rd, t);
    
    if(d < 20.0) {
        vec3 p = ro + rd * d;
        vec3 n = calcNormal(p, t);
        
        // Lighting. lightDir is a compile-time constant, so the normalize is
        // folded to precomputed components.
        const vec3 lightDir = vec3(0.408248290463863, 0.816496580927726, 0.408248290463863);
        float diff = max(dot(n, lightDir), 0.0);

        // pow(x, 32.0) as a squaring chain: 5 multiplies instead of a
        // log2 + exp2 pair.
        float spec = max(dot(reflect(-lightDir, n), -rd), 0.0);
        spec *= spec; spec *= spec; spec *= spec; spec *= spec; spec *= spec;

        // Rainbow colour. The three channels are cos of one angle plus the
        // constant offsets 0.0, 0.5 and 1.0 rad, so one sin/cos pair covers
        // all three.
        float ra = t + p.y * 2.0;
        float raS = sin(ra), raC = cos(ra);
        vec3 mushroomCol = 0.5 + 0.5 * vec3(
            raC,
            raC * 0.877582561890373 - raS * 0.479425538604203,
            raC * 0.540302305868140 - raS * 0.841470984807897
        );
        
        col = mushroomCol * (0.2 + 0.8 * diff) + vec3(0.5) * spec;
        
        // Glow
        col += mushroomCol * 0.3;
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    return vec4(col * intensity, alpha);
}
