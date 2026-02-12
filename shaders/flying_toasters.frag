#include "base/common.glsl"

// --- SDF Helpers ---
float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

mat3 rotateY(float a) {
    float s = sin(a), c = cos(a);
    return mat3(c, 0, s, 0, 1, 0, -s, 0, c);
}

mat3 rotateZ(float a) {
    float s = sin(a), c = cos(a);
    return mat3(c, s, 0, -s, c, 0, 0, 0, 1);
}

mat3 rotateX(float a) {
    float s = sin(a), c = cos(a);
    return mat3(1, 0, 0, 0, c, s, 0, -s, c);
}

// --- Toaster SDF ---
float mapToaster(vec3 p, float t, float id) {
    // Center alignment
    p.y -= 0.05;
    
    // Body of the toaster
    float body = sdRoundBox(p, vec3(0.15, 0.12, 0.15), 0.03);
    
    // Slots
    float slot1 = sdBox(p - vec3(0.04, 0.08, 0.0), vec3(0.015, 0.1, 0.12));
    float slot2 = sdBox(p - vec3(-0.04, 0.08, 0.0), vec3(0.015, 0.1, 0.12));
    float d = max(body, -min(slot1, slot2));
    
    // Lever
    float lever = sdRoundBox(p - vec3(0.16, 0.0, 0.08), vec3(0.02, 0.01, 0.04), 0.01);
    d = min(d, lever);
    
    // Wings
    float wingAngle = sin(t * 8.0 + id) * 1.0;
    
    // Right wing
    vec3 pRW = p - vec3(0.12, 0.08, 0.0);
    pRW = rotateZ(wingAngle) * pRW;
    float rightWing = sdRoundBox(pRW - vec3(0.1, 0.0, 0.0), vec3(0.1, 0.01, 0.12), 0.01);
    
    // Left wing
    vec3 pLW = p - vec3(-0.12, 0.08, 0.0);
    pLW = rotateZ(-wingAngle) * pLW;
    float leftWing = sdRoundBox(pLW + vec3(0.1, 0.0, 0.0), vec3(0.1, 0.01, 0.12), 0.01);
    
    d = min(d, min(rightWing, leftWing));
    
    return d;
}

vec3 getNormal(vec3 p, float t, float id) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        mapToaster(p + e.xyy, t, id) - mapToaster(p - e.xyy, t, id),
        mapToaster(p + e.yxy, t, id) - mapToaster(p - e.yxy, t, id),
        mapToaster(p + e.yyx, t, id) - mapToaster(p - e.yyx, t, id)
    ));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.4;
    
    // Background stars
    vec3 color = vec3(0.01, 0.01, 0.02);
    vec2 starUV = uv * 10.0;
    float star = fract(sin(dot(floor(starUV), vec2(12.9898, 78.233))) * 43758.5453);
    if (star > 0.99) {
        float blink = 0.5 + 0.5 * sin(t * 2.0 + star * 10.0);
        color += vec3(blink);
    }
    
    // Raymarching
    vec3 ro = vec3(0.0, 0.0, 4.0);
    vec3 rd = normalize(vec3(centered, -2.5));
    
    // Rotate camera slightly
    mat3 camRot = rotateY(sin(t * 0.1) * 0.2) * rotateX(sin(t * 0.15) * 0.1);
    ro = camRot * ro;
    rd = camRot * rd;
    
    float t_dist = 0.0;
    bool hit = false;
    vec3 p;
    float finalID = 0.0;
    
    // Flying logic with domain repetition
    float cellSize = 2.0;
    
    for (int i = 0; i < 64; i++) {
        p = ro + rd * t_dist;
        
        // Classic flying toaster movement: top-right to bottom-left
        vec3 moveP = p;
        moveP.x += t * 1.5;
        moveP.y += t * 1.0;
        moveP.z += t * 0.5;
        
        vec3 id = floor(moveP / cellSize);
        vec3 localP = fract(moveP / cellSize) * cellSize - cellSize * 0.5;
        
        // Scramble cell content
        float seed = fract(sin(dot(id, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
        vec3 offset = (vec3(
            fract(seed * 1.1),
            fract(seed * 1.2),
            fract(seed * 1.3)
        ) - 0.5) * cellSize * 0.6;
        
        // Random rotation for each toaster
        mat3 rot = rotateY(seed * 6.28 + t * 0.5) * rotateX(seed * 3.14);
        
        float d = mapToaster(rot * (localP - offset), t + seed * 10.0, seed * 5.0);
        
        if (d < 0.001) {
            hit = true;
            finalID = seed;
            break;
        }
        
        if (t_dist > 15.0) break;
        t_dist += d;
    }
    
    if (hit) {
        // Recalculate normal in local space
        vec3 moveP = p;
        moveP.x += t * 1.5; moveP.y += t * 1.0; moveP.z += t * 0.5;
        vec3 id = floor(moveP / cellSize);
        vec3 localP = fract(moveP / cellSize) * cellSize - cellSize * 0.5;
        float seed = fract(sin(dot(id, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
        vec3 offset = (vec3(fract(seed * 1.1), fract(seed * 1.2), fract(seed * 1.3)) - 0.5) * cellSize * 0.6;
        mat3 rot = rotateY(seed * 6.28 + t * 0.5) * rotateX(seed * 3.14);
        
        vec3 localNorm = getNormal(rot * (localP - offset), t + seed * 10.0, seed * 5.0);
        vec3 worldNorm = transpose(rot) * localNorm;
        
        vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
        float diff = max(0.1, dot(worldNorm, lightDir));
        
        // Chrome/Metal look
        vec3 reflection = reflect(rd, worldNorm);
        float spec = pow(max(0.0, dot(reflection, lightDir)), 32.0);
        
        vec3 metalColor = vec3(0.9, 0.85, 0.8);
        color = metalColor * diff + vec3(spec);
        
        // Rim lighting for pop
        float rim = pow(1.0 - max(0.0, dot(worldNorm, -rd)), 4.0);
        color += vec3(0.5, 0.4, 0.3) * rim;
        
        // Atmospheric depth
        color = mix(color, vec3(0.01, 0.01, 0.02), clamp(t_dist / 15.0, 0.0, 1.0));
    }
    
    color *= intensity;
    return vec4(color, alpha);
}
