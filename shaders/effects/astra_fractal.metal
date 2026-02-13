//
//  astra_fractal.metal
//  ShaderCandy
//
//  3D Mandelbox fractal tunnel with psychedelic color shifts
//

using namespace ShaderUtils;

// Mandelbox Fold
void boxFold(thread float3& z, thread float& dz) {
    z = clamp(z, -1.0, 1.0) * 2.0 - z;
}

void sphereFold(thread float3& z, thread float& dz) {
    float r2 = dot(z, z);
    if (r2 < 0.5) {
        float temp = 2.0;
        z *= temp;
        dz *= temp;
    } else if (r2 < 1.0) {
        float temp = 1.0 / r2;
        z *= temp;
        dz *= temp;
    }
}

float mboxSDF(float3 p, float t) {
    float3 z = p;
    float dr = 1.0;
    float scale = 2.6 + 0.2 * sin(t * 0.5);
    
    for (int i = 0; i < 10; i++) {
        boxFold(z, dr);
        sphereFold(z, dr);
        z = scale * z + p;
        dr = dr * abs(scale) + 1.0;
    }
    return length(z) / abs(dr);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Camera
    float3 ro = float3(0.0, 0.0, -4.0 + sin(t * 0.2));
    float3 ta = float3(sin(t * 0.1), cos(t * 0.15), 0.0);
    float3 fwd = normalize(ta - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Raymarch
    float d = 0.0, t_dist = 0.0;
    for (int i = 0; i < 100; i++) {
        d = mboxSDF(ro + rd * t_dist, t);
        if (d < 0.001 || t_dist > 10.0) break;
        t_dist += d;
    }
    
    float3 color = float3(0.0);
    if (t_dist < 10.0) {
        float3 p = ro + rd * t_dist;
        float3 normal = normalize(float3(
            mboxSDF(p + float3(0.001, 0, 0), t) - mboxSDF(p - float3(0.001, 0, 0), t),
            mboxSDF(p + float3(0, 0.001, 0), t) - mboxSDF(p - float3(0, 0.001, 0), t),
            mboxSDF(p + float3(0, 0, 0.001), t) - mboxSDF(p - float3(0, 0, 0.001), t)
        ));
        
        float diff = max(0.0, dot(normal, normalize(float3(1, 2, -3))));
        float3 hsv = float3(fract(t_dist * 0.2 + t * 0.1), 0.8, 1.0);
        color = hsv2rgb(hsv) * diff;
        color += exp(-t_dist * 0.5) * hsv2rgb(float3(fract(t * 0.5), 0.5, 1.0));
    } else {
        color = float3(0.05, 0.0, 0.1) * (1.0 - length(uv) * 0.5);
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
