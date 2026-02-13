//
//  mind_palace.metal
//  ShaderCandy
//
//  Infinite shifting architectural rooms with glowing hieroglyphs
//

using namespace ShaderUtils;

float palaceSDF(float3 p, float t) {
    float3 q = p;
    q = mod(q, 4.0) - 2.0;
    
    // Box frame
    float3 d = abs(q) - 1.8;
    float box = min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
    
    // Hollow out
    float3 d2 = abs(q) - 1.7;
    float hollow = min(max(d2.x, max(d2.y, d2.z)), 0.0) + length(max(d2, 0.0));
    box = max(box, -hollow);
    
    // Internal pillars
    float pillars = length(q.xz) - 0.1;
    pillars = min(pillars, length(q.xy) - 0.1);
    pillars = min(pillars, length(q.yz) - 0.1);
    
    return min(box, pillars);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float3 ro = float3(1.0 + t, 1.0 + sin(t * 0.5), t);
    float3 rd = normalize(float3(uv, 1.0));
    rd = rotX(t * 0.1) * rotY(t * 0.15) * rd;
    
    float td = 0.0, d;
    float3 color = float3(0.0);
    float glow = 0.0;
    
    for (int i = 0; i < 80; i++) {
        float3 p = ro + rd * td;
        d = palaceSDF(p, t);
        if (d < 0.001 || td > 20.0) break;
        td += d;
        glow += 0.01 / (1.0 + d * 20.0);
    }
    
    if (td < 20.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            palaceSDF(p + float3(0.01, 0, 0), t) - palaceSDF(p - float3(0.01, 0, 0), t),
            palaceSDF(p + float3(0, 0.01, 0), t) - palaceSDF(p - float3(0, 0.01, 0), t),
            palaceSDF(p + float3(0, 0, 0.01), t) - palaceSDF(p - float3(0, 0, 0.01), t)
        ));
        
        float pattern = step(0.9, fract(p.x * 2.0 + t)) + step(0.9, fract(p.y * 2.0)) + step(0.9, fract(p.z * 2.0));
        color = mix(float3(0.05, 0.1, 0.2), hsv2rgb(float3(fract(t * 0.1), 0.8, 1.0)), pattern);
        color *= max(0.2, dot(n, normalize(float3(1, 1, -1))));
    }
    
    color += glow * hsv2rgb(float3(fract(t * 0.05), 0.7, 1.0));
    color *= exp(-td * 0.1);
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
