#version 450 core

#include "../base/common.glsl"

// Reaction-Diffusion (Gray-Scott & Turing Morphogenesis)
// Procedural multi-frequency reaction-diffusion simulation with dynamic parameter exploration,
// audio reactivity, and 3D surface relief lighting.

// Procedural concentration field evaluated through multi-scale coupled Turing synthesis
vec2 evaluateChemicals(vec2 p, float t, float feed, float kill) {
    vec2 state = vec2(1.0, 0.0); // U = 1.0 (ambient substrate), V = 0.0 (reactant)

    // Domain warping to simulate fluid convective advection of reagents
    vec2 warp = vec2(
        snoise(vec3(p * 0.8, t * 0.05)),
        snoise(vec3(p * 0.8 + vec2(43.1, 17.4), t * 0.05))
    ) * 0.35;

    vec2 q = p + warp;

    // Multi-scale reaction-diffusion waves
    float vSum = 0.0;
    float weightSum = 0.0;

    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float scale = pow(1.85, fi) * 1.5;
        float weight = 1.0 / pow(1.4, fi);

        // Directional diffusion wave rotation
        float angle = fi * 1.2566 + t * 0.02 * (mod(fi, 2.0) == 0.0 ? 1.0 : -1.0);
        mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
        vec2 sp = rot * q * scale;

        // Coupled activator-inhibitor harmonic dynamics
        float a = sin(sp.x + sin(sp.y * 1.2 + t * 0.1)) * cos(sp.y + cos(sp.x * 1.1 - t * 0.08));
        float b = cos(sp.x * 0.9 - sp.y * 0.8 + t * 0.06);

        // Non-linear Gray-Scott reaction term approximation
        float localReact = a * a * b;
        float localV = smoothstep(kill * 8.0, feed * 12.0, localReact + 0.5 * (a + 1.0));

        vSum += localV * weight;
        weightSum += weight;
    }

    float v = clamp(vSum / weightSum, 0.0, 1.0);

    // Non-linear reaction saturation
    float reaction = (1.0 - v) * v * v;
    float u = clamp(1.0 - v * 0.9 - reaction * 2.0, 0.0, 1.0);

    return vec2(u, v);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.4;

    // Interactive mouse reagent seeding
    vec2 mPos = (mouse - 0.5) * 2.0;
    mPos.x *= resolution.x / max(resolution.y, 1.0);
    float mouseDist = length(centered - mPos);
    float mouseInfluence = smoothstep(0.4, 0.0, mouseDist) * (mouseButtons > 0.5 ? 1.5 : 0.4);

    // Audio reagent perturbation
    float audioBoost = (bass * 0.8 + volume * 0.5 + beat * 0.4);

    // Scale coordinate space for optimal morphological pattern formation
    vec2 p = centered * (3.5 + sin(t * 0.05) * 0.5);

    // Dynamic Gray-Scott Pearson parameters exploring labyrinths, coral, spots, and chaos
    float feed = 0.0545 + sin(t * 0.2) * 0.012 + audioBoost * 0.008;
    float kill = 0.0620 + cos(t * 0.15) * 0.006 - audioBoost * 0.004;

    // Sample chemical concentrations
    vec2 chem = evaluateChemicals(p, t, feed, kill);

    // Inject reactant near mouse
    chem.y = clamp(chem.y + mouseInfluence * 0.6, 0.0, 1.0);
    chem.x = clamp(chem.x - mouseInfluence * 0.3, 0.0, 1.0);

    // Calculate normal from chemical concentration gradient for 3D specular relief
    vec2 eps = vec2(2.0 / resolution.y, 0.0);
    float hC = chem.y;
    float hR = evaluateChemicals(p + eps.xy * 3.0, t, feed, kill).y;
    float hU = evaluateChemicals(p + eps.yx * 3.0, t, feed, kill).y;
    vec3 normal = normalize(vec3((hC - hR) * 15.0, (hC - hU) * 15.0, 1.0));

    // Directional lighting
    vec3 lightDir = normalize(vec3(0.5, 0.8, 1.2));
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfDir), 0.0), 32.0);

    // Vibrant Pearson morphogenetic color mapping
    vec3 cBg = vec3(0.02, 0.04, 0.12);         // Deep oceanic midnight
    vec3 cMedium = vec3(0.05, 0.35, 0.65);     // Bioluminescent sapphire
    vec3 cReactant = vec3(0.0, 0.85, 0.75);    // Electric seafoam / emerald teal
    vec3 cCore = vec3(1.0, 0.82, 0.25);        // Fluorescent solar gold
    vec3 cEdge = vec3(0.95, 0.2, 0.5);         // Reaction boundary magenta

    // Layered color mixing based on chemical concentrations
    float vVal = chem.y;
    float uVal = chem.x;

    vec3 col = mix(cBg, cMedium, smoothstep(0.05, 0.35, vVal));
    col = mix(col, cReactant, smoothstep(0.35, 0.65, vVal));
    col = mix(col, cCore, smoothstep(0.65, 0.95, vVal));

    // Edge enhancement along chemical boundary gradient
    float edge = length(vec2(hC - hR, hC - hU)) * 10.0;
    col += cEdge * smoothstep(0.2, 0.8, edge) * 0.6;

    // Apply 3D relief lighting & specular shine
    col = col * (0.35 + 0.65 * diff) + vec3(1.0, 0.95, 0.85) * spec * 0.45;

    // Subsurface chemical luminescence
    col += cReactant * pow(vVal, 2.0) * (0.3 + 0.3 * sin(t * 1.5 + vVal * 6.28));

    // Audio reactivity flash on beats
    col += vec3(0.2, 0.4, 0.8) * beat * 0.25 * vVal;

    // Vignette
    col *= 1.0 - length(centered) * 0.25;
    col *= intensity;

    return vec4(col, alpha);
}
