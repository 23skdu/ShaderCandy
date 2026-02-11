#version 450 core

#include "../base/common.glsl"

// DNA Double Helix - Molecular visualization

// Rotate point around axis
vec3 rotateAroundAxis(vec3 p, vec3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0 - c;
    
    vec3 a = normalize(axis);
    
    mat3 rot = mat3(
        t * a.x * a.x + c,        t * a.x * a.y - s * a.z,  t * a.x * a.z + s * a.y,
        t * a.x * a.y + s * a.z,  t * a.y * a.y + c,        t * a.y * a.z - s * a.x,
        t * a.x * a.z - s * a.y,  t * a.y * a.z + s * a.x,  t * a.z * a.z + c
    );
    
    return rot * p;
}

// Sphere SDF
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

// Cylinder SDF
float sdCylinder(vec3 p, float r, float h) {
    vec2 d = vec2(length(p.xz) - r, abs(p.y) - h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// DNA helix SDF
float sdDNA(vec3 p, float t) {
    // Helix parameters
    float radius = 0.3;
    float pitch = 0.8;
    
    // Create two strands
    float strand1 = 1000.0;
    float strand2 = 1000.0;
    
    // Twist parameter
    float twist = p.y * pitch + t * 0.5;
    
    // Strand 1 positions
    vec3 basePos1 = vec3(
        cos(twist) * radius,
        p.y,
        sin(twist) * radius
    );
    
    // Strand 2 positions (opposite)
    vec3 basePos2 = vec3(
        cos(twist + PI) * radius,
        p.y,
        sin(twist + PI) * radius
    );
    
    // Distance to strands
    strand1 = length(p - basePos1) - 0.04;
    strand2 = length(p - basePos2) - 0.04;
    
    // Base pairs (connecting rungs)
    float rung = 1000.0;
    float rungSpacing = 0.15;
    float yOffset = mod(p.y + 100.0, rungSpacing) - rungSpacing * 0.5;
    
    if (abs(yOffset) < 0.02) {
        vec3 rungPos = vec3(p.x * 0.5, basePos1.y, p.z * 0.5);
        rung = sdCylinder(rungPos - vec3(0.0, 0.0, 0.0), 0.015, radius * 0.9);
    }
    
    // Combine
    float dna = min(strand1, strand2);
    dna = min(dna, rung);
    
    return dna;
}

// Scene mapping
float map(vec3 p, float t) {
    return sdDNA(p, t);
}

// Calculate normal
vec3 calcNormal(vec3 p, float t) {
    float eps = 0.001;
    return normalize(vec3(
        map(p + vec3(eps, 0, 0), t) - map(p - vec3(eps, 0, 0), t),
        map(p + vec3(0, eps, 0), t) - map(p - vec3(0, eps, 0), t),
        map(p + vec3(0, 0, eps), t) - map(p - vec3(0, 0, eps), t)
    ));
}

// Ray marching
float rayMarch(vec3 ro, vec3 rd, float t) {
    float d = 0.0;
    for (int i = 0; i < 100; i++) {
        vec3 p = ro + rd * d;
        float dist = map(p, t);
        if (dist < 0.001 || d > 20.0) break;
        d += dist;
    }
    return d;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    // Camera setup
    float t = time * 0.3;
    
    vec3 ro = vec3(
        sin(t) * 1.5,
        sin(t * 0.5) * 0.5,
        cos(t) * 1.5
    );
    vec3 ta = vec3(0.0, 0.0, 0.0);
    
    // Camera matrix
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0, 1, 0)));
    vec3 vv = cross(uu, ww);
    
    // Ray direction
    vec3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Ray march
    float dist = rayMarch(ro, rd, time);
    
    // Background
    vec3 col = vec3(0.02, 0.02, 0.05);
    
    if (dist < 20.0) {
        vec3 pos = ro + dist * rd;
        vec3 nor = calcNormal(pos, time);
        
        // Lighting
        vec3 light = normalize(vec3(1.0, 2.0, 1.0));
        float dif = max(dot(nor, light), 0.0);
        
        // Strand coloring
        float strandID = sin(pos.y * 10.0 + time);
        vec3 strandColor = mix(
            vec3(0.8, 0.3, 0.2),  // Red (adenine/guanine)
            vec3(0.2, 0.5, 0.9),  // Blue (thymine/cytosine)
            smoothstep(-0.5, 0.5, strandID)
        );
        
        // Rungs are different color
        if (abs(mod(pos.y + 100.0, 0.15) - 0.075) < 0.02) {
            strandColor = vec3(0.9, 0.9, 0.3);  // Yellow rungs
        }
        
        // Fresnel
        float fre = pow(1.0 - max(dot(nor, -rd), 0.0), 3.0);
        
        // Combine
        col = strandColor * dif * 0.8;
        col += vec3(0.5) * fre;
        
        // Fog
        float fog = exp(-dist * 0.2);
        col = mix(vec3(0.02, 0.02, 0.05), col, fog);
    }
    
    // Add glowing particles (energy/molecules)
    for (int i = 0; i < 30; i++) {
        float fi = float(i);
        vec3 particlePos = vec3(
            sin(fi * 0.7 + t) * (0.8 + fi * 0.02),
            cos(fi * 0.5 + t * 0.8) * 0.4,
            sin(fi * 0.3 + t * 0.6) * (0.8 + fi * 0.02)
        );
        
        // Ray-sphere intersection
        vec3 oc = ro - particlePos;
        float b = dot(oc, rd);
        float c = dot(oc, oc) - 0.01;
        float h = b * b - c;
        
        if (h > 0.0) {
            float d = -b - sqrt(h);
            if (d > 0.0 && d < dist) {
                vec3 glowColor = hsv2rgb(vec3(fi / 30.0 + t * 0.1, 0.9, 1.0));
                col += glowColor * 0.1 * (1.0 - d / dist);
            }
        }
    }
    
    // Post-processing
    col = pow(col, vec3(0.4545));
    col *= 1.0 - length(centered) * 0.2;
    
    return vec4(col, 1.0);
}
