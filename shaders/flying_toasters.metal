// Flying Toasters 3D
// Raymarching implementation of the classic screensaver

// --- SDF Helpers ---
float sdRoundBox(float3 p, float3 b, float r) {
    float3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// function sdBox removed (using utils.metal version)

// Rotation matrix
float3x3 rotateY(float a) {
    float s = sin(a), c = cos(a);
    return float3x3(c, 0, s, 0, 1, 0, -s, 0, c);
}

float3x3 rotateZ(float a) {
    float s = sin(a), c = cos(a);
    return float3x3(c, s, 0, -s, c, 0, 0, 0, 1);
}

float3x3 rotateX(float a) {
    float s = sin(a), c = cos(a);
    return float3x3(1, 0, 0, 0, c, s, 0, -s, c);
}

// --- Toaster SDF ---
float mapToaster(float3 p, float t, float id) {
    // Center alignment
    p.y -= 0.05;
    
    // Body of the toaster
    float body = sdRoundBox(p, float3(0.15, 0.12, 0.15), 0.03);
    
    // Slots
    float slot1 = sdBox(p - float3(0.04, 0.08, 0.0), float3(0.015, 0.1, 0.12));
    float slot2 = sdBox(p - float3(-0.04, 0.08, 0.0), float3(0.015, 0.1, 0.12));
    float d = max(body, -min(slot1, slot2));
    
    // Lever
    float lever = sdRoundBox(p - float3(0.16, 0.0, 0.08), float3(0.02, 0.01, 0.04), 0.01);
    d = min(d, lever);
    
    // Wings
    float wingAngle = sin(t * 8.0 + id) * 1.0;
    
    // Right wing
    float3 pRW = p - float3(0.12, 0.08, 0.0);
    pRW = rotateZ(wingAngle) * pRW;
    float rightWing = sdRoundBox(pRW - float3(0.1, 0.0, 0.0), float3(0.1, 0.01, 0.12), 0.01);
    
    // Left wing
    float3 pLW = p - float3(-0.12, 0.08, 0.0);
    pLW = rotateZ(-wingAngle) * pLW;
    float leftWing = sdRoundBox(pLW + float3(0.1, 0.0, 0.0), float3(0.1, 0.01, 0.12), 0.01);
    
    d = min(d, min(rightWing, leftWing));
    
    return d;
}

float3 getNormal(float3 p, float t, float id) {
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        mapToaster(p + e.xyy, t, id) - mapToaster(p - e.xyy, t, id),
        mapToaster(p + e.yxy, t, id) - mapToaster(p - e.yxy, t, id),
        mapToaster(p + e.yyx, t, id) - mapToaster(p - e.yyx, t, id)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]],
                             texture2d<float> toasterTexture [[texture(0)]],
                             sampler toasterSampler [[sampler(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed * 0.4;
    
    // Background stars
    float3 color = float3(0.01, 0.01, 0.02);
    float2 starUV = in.texCoord * 10.0;
    float star = fract(sin(dot(floor(starUV), float2(12.9898, 78.233))) * 43758.5453);
    if (star > 0.99) {
        float blink = 0.5 + 0.5 * sin(t * 2.0 + star * 10.0);
        color += float3(blink);
    }
    
    // Raymarching
    float3 ro = float3(0.0, 0.0, 4.0);
    float3 rd = normalize(float3(uv, -2.5));
    
    // Rotate camera slightly
    float3x3 camRot = rotateY(sin(t * 0.1) * 0.2) * rotateX(sin(t * 0.15) * 0.1);
    ro = camRot * ro;
    rd = camRot * rd;
    
    float t_dist = 0.0;
    bool hit = false;
    float3 p;
    float finalID = 0.0;
    
    // Flying logic with domain repetition
    // Space is subdivided into cells
    float cellSize = 2.0;
    
    for (int i = 0; i < 64; i++) {
        p = ro + rd * t_dist;
        
        // Classic flying toaster movement: top-right to bottom-left
        float3 moveP = p;
        moveP.x += t * 1.5;
        moveP.y += t * 1.0;
        moveP.z += t * 0.5;
        
        float3 id = floor(moveP / cellSize);
        float3 localP = fract(moveP / cellSize) * cellSize - cellSize * 0.5;
        
        // Scramble cell content
        float seed = fract(sin(dot(id, float3(12.9898, 78.233, 45.164))) * 43758.5453);
        float3 offset = (float3(
            fract(seed * 1.1),
            fract(seed * 1.2),
            fract(seed * 1.3)
        ) - 0.5) * cellSize * 0.6;
        
        // Random rotation for each toaster
        float3x3 rot = rotateY(seed * 6.28 + t * 0.5) * rotateX(seed * 3.14);
        
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
        float3 norm = getNormal(p, t, finalID); // This is not quite right because of rotations, but let's fix if weird
        // Recalculate normal in local space
        float3 moveP = p;
        moveP.x += t * 1.5; moveP.y += t * 1.0; moveP.z += t * 0.5;
        float3 id = floor(moveP / cellSize);
        float3 localP = fract(moveP / cellSize) * cellSize - cellSize * 0.5;
        float seed = fract(sin(dot(id, float3(12.9898, 78.233, 45.164))) * 43758.5453);
        float3 offset = (float3(fract(seed * 1.1), fract(seed * 1.2), fract(seed * 1.3)) - 0.5) * cellSize * 0.6;
        float3x3 rot = rotateY(seed * 6.28 + t * 0.5) * rotateX(seed * 3.14);
        
        float3 localNorm = getNormal(rot * (localP - offset), t + seed * 10.0, seed * 5.0);
        float3 worldNorm = transpose(rot) * localNorm; // Undo rotation for lighting
        
        float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
        float diff = max(0.1, dot(worldNorm, lightDir));
        
        // Chrome/Metal look
        float3 reflection = reflect(rd, worldNorm);
        float spec = pow(max(0.0, dot(reflection, lightDir)), 32.0);
        
        float3 metalColor = float3(0.9, 0.85, 0.8); // Stainless steel
        color = metalColor * diff + float3(spec);
        
        // Rim lighting for pop
        float rim = pow(1.0 - max(0.0, dot(worldNorm, -rd)), 4.0);
        color += float3(0.5, 0.4, 0.3) * rim;
        
        // Atmospheric depth
        color = mix(color, float3(0.01, 0.01, 0.02), saturate(t_dist / 15.0));
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
