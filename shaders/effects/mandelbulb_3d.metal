// Mandelbulb 3D Fractal
// Raymarching implementation

// Mandelbulb distance estimator
float map(float3 p, thread float& trap) {
    float3 z = p;
    float dr = 1.0;
    float r = 0.0;
    float Power = 8.0;
    
    for (int i = 0; i < 8; i++) {
        r = length(z);
        if (r > 2.0) break;
        
        // Convert to polar coordinates
        float theta = acos(z.z / r);
        float phi = atan2(z.y, z.x);
        dr = pow(r, Power - 1.0) * Power * dr + 1.0;
        
        // Scale and rotate z
        float zr = pow(r, Power);
        theta = theta * Power;
        phi = phi * Power;
        
        // Convert back to cartesian coordinates
        z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
        z += p;
        
        trap = min(trap, length(z));
    }
    return 0.5 * log(r) * r / dr;
}

float3 getNormal(float3 p) {
    float dummy = 0.0;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + e.xyy, dummy) - map(p - e.xyy, dummy),
        map(p + e.yxy, dummy) - map(p - e.yxy, dummy),
        map(p + e.yyx, dummy) - map(p - e.yyx, dummy)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * 0.2;
    
    // Camera setup
    float3 ro = float3(2.5 * sin(t), 1.5 * cos(t * 0.5), 2.5 * cos(t));
    float3 lookat = float3(0.0);
    float3 fwd = normalize(lookat - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Raymarching
    float d = 0.0;
    float t_dist = 0.0;
    float trap = 1e10;
    float3 p;
    
    for (int i = 0; i < 128; i++) {
        p = ro + rd * t_dist;
        d = map(p, trap);
        if (d < 0.001 || t_dist > 10.0) break;
        t_dist += d;
    }
    
    float3 color = float3(0.0);
    if (t_dist < 10.0) {
        float3 norm = getNormal(p);
        float3 lightPos = float3(5.0, 5.0, 5.0);
        float3 lightDir = normalize(lightPos - p);
        float diff = max(0.0, dot(norm, lightDir));
        
        // Coloring based on orbit trap
        float3 trapColor = 0.5 + 0.5 * sin(float3(trap * 3.0, trap * 3.0 + 2.0, trap * 3.0 + 4.0));
        color = trapColor * (diff + 0.1);
        
        // Fog
        color = mix(color, float3(0.0), 1.0 - exp(-0.1 * t_dist));
    }
    
    return float4(color, uniforms.alpha);
}
