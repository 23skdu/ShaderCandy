// 3D Quaternion Julia Set
// Raymarching implementation

// Quaternion multiplication
float4 qMul(float4 q1, float4 q2) {
    return float4(
        q1.x * q2.x - q1.y * q2.y - q1.z * q2.z - q1.w * q2.w,
        q1.x * q2.y + q1.y * q2.x + q1.z * q2.w - q1.w * q2.z,
        q1.x * q2.z - q1.y * q2.w + q1.z * q2.x + q1.w * q2.y,
        q1.x * q2.w + q1.y * q2.z - q1.z * q2.y + q1.w * q2.x
    );
}

// Julia Set distance estimator
float map(float3 p, float4 c, thread float& trap) {
    float4 z = float4(p, 0.0);
    float m2 = dot(z, z);
    float dz2 = 1.0;
    
    for (int i = 0; i < 10; i++) {
        // Derivative for distance estimation
        dz2 *= 4.0 * m2;
        
        // z = z^2 + c
        z = qMul(z, z) + c;
        
        m2 = dot(z, z);
        if (m2 > 10.0) break;
        
        trap = min(trap, m2);
    }
    
    return 0.25 * sqrt(m2 / dz2) * log(m2);
}

float3 getNormal(float3 p, float4 c) {
    float dummy = 0.0;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + e.xyy, c, dummy) - map(p - e.xyy, c, dummy),
        map(p + e.yxy, c, dummy) - map(p - e.yxy, c, dummy),
        map(p + e.yyx, c, dummy) - map(p - e.yyx, c, dummy)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.y > 0 ? uniforms.resolution.x / uniforms.resolution.y : 1.0;
    uv.x *= aspect;
    
    float t = uniforms.time * 0.3;
    
    // Animate Julia constant C
    float4 c = float4(-0.2, 0.6 * sin(t * 0.4), 0.4 * cos(t * 0.3), 0.2 * sin(t * 0.5));
    
    // Camera
    float3 ro = float3(2.0 * sin(t * 0.5), 1.0 * cos(t * 0.2), 2.0 * cos(t * 0.5));
    float3 lookat = float3(0.0);
    float3 fwd = normalize(lookat - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    float t_dist = 0.0;
    float trap = 1e10;
    float d = 0.0;
    float3 p;
    
    for (int i = 0; i < 100; i++) {
        p = ro + rd * t_dist;
        d = map(p, c, trap);
        if (d < 0.001 || t_dist > 8.0) break;
        t_dist += d;
    }
    
    float3 color = float3(0.05, 0.05, 0.1); // Background
    if (t_dist < 8.0) {
        float3 norm = getNormal(p, c);
        float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
        float diff = max(0.1, dot(norm, lightDir));
        
        float3 baseCol = 0.5 + 0.5 * sin(float3(0.0, 2.0, 4.0) + trap * 2.0);
        color = baseCol * diff;
        
        // Specular
        float3 ref = reflect(lightDir, norm);
        float spec = pow(max(0.0, dot(ref, rd)), 16.0);
        color += float3(spec);
    }
    
    return float4(color, uniforms.alpha);
}
