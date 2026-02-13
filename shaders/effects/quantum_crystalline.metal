//
//  quantum_crystalline.metal
//  ShaderCandy
//
//  Infinite crystalline fractal geometry with rainbow refraction
//

using namespace ShaderUtils;

float crystalSDF(float3 p, float t) {
    float3 q = p;
    float s = 1.0;
    for (int i = 0; i < 6; i++) {
        q = abs(q) - 1.2;
        float r2 = dot(q, q);
        float k = 1.5 / r2;
        q *= k;
        s *= k;
        q = rotX(0.2 * t) * q;
        q = rotY(0.3 * t) * q;
    }
    return (length(q) - 0.5) / s;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float3 ro = float3(0, 0, -3.5);
    float3 rd = normalize(float3(uv, 2.0));
    rd = rotY(t * 0.1) * rd;
    
    float d, td = 0.0;
    float3 color = float3(0.0);
    
    for (int i = 0; i < 64; i++) {
        float3 p = ro + rd * td;
        d = crystalSDF(p, t);
        if (d < 0.001 || td > 10.0) break;
        td += d;
        // Glow accumulation
        color += 0.005 * hsv2rgb(float3(fract(td * 0.1 + t * 0.05), 0.7, 1.0));
    }
    
    if (td < 10.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            crystalSDF(p + float3(0.01, 0, 0), t) - crystalSDF(p - float3(0.01, 0, 0), t),
            crystalSDF(p + float3(0, 0.01, 0), t) - crystalSDF(p - float3(0, 0.01, 0), t),
            crystalSDF(p + float3(0, 0, 0.01), t) - crystalSDF(p - float3(0, 0, 0.01), t)
        ));
        float fre = pow(1.0 + dot(rd, n), 3.0);
        color += fre * hsv2rgb(float3(fract(td * 0.5), 0.8, 1.0));
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
