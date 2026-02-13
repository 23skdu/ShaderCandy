//
//  biolume_forest.metal
//  ShaderCandy
//
//  Organic glowing mushrooms and vines in a dark void
//

using namespace ShaderUtils;

float forestSDF(float3 p, float t) {
    float3 q = p;
    q.xz = mod(q.xz, 4.0) - 2.0;
    
    // Mushroom stalk
    float stalk = length(q.xz) - 0.2 * (1.0 - exp(-p.y * 2.0));
    stalk = max(stalk, p.y - 1.5);
    stalk = max(stalk, -p.y);
    
    // Mushroom cap
    float cap = length(float3(q.x, q.y - 1.5, q.z)) - 0.8;
    cap = max(cap, -(length(float3(q.x, q.y - 1.3, q.z)) - 0.75));
    cap = max(cap, p.y - 1.6);
    
    // Ground
    float ground = p.y + 0.1 * snoise(p.xz * 0.5 + t * 0.1);
    
    return min(ground, min(stalk, cap));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    float3 ro = float3(2.0 * sin(t * 0.2), 1.0 + 0.5 * cos(t * 0.1), t * 1.5);
    float3 rd = normalize(float3(uv, 1.2));
    rd = rotY(0.1 * sin(t * 0.3)) * rd;
    
    float td = 0.0, d;
    float glow = 0.0;
    for (int i = 0; i < 80; i++) {
        float3 p = ro + rd * td;
        d = forestSDF(p, t);
        if (d < 0.001 || td > 20.0) break;
        td += d;
        glow += 0.01 / (1.0 + d * 20.0);
    }
    
    float3 color = float3(0.0);
    if (td < 20.0) {
        float3 p = ro + rd * td;
        float3 hsv = float3(0.5 + 0.3 * sin(p.x * 0.5 + t), 0.7, 0.8);
        color = hsv2rgb(hsv) * exp(-td * 0.1);
    }
    
    color += glow * hsv2rgb(float3(0.6 + 0.2 * sin(t * 0.5), 0.8, 1.0));
    color *= exp(-td * 0.15); // Fog
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
