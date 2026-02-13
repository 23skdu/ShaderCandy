//
//  area_51.metal
//  ShaderCandy
//
//  Aliens and UFO sighting at a secret desert base
//

using namespace ShaderUtils;

float ufoSDF(float3 p, float t) {
    // Rotating flying saucer
    p = rotateY(p, t * 0.5);
    float body = length(p * float3(1.0, 3.0, 1.0)) - 0.8;
    float ring = length(float2(length(p.xz) - 0.8, p.y)) - 0.05;
    float ufo = min(body, ring);
    
    // Dome
    float dome = length(p - float3(0, 0.1, 0)) - 0.4;
    dome = max(dome, p.y);
    return min(ufo, dome);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Background: Desert Night
    float3 color = mix(float3(0.01, 0.01, 0.05), float3(0.05, 0.02, 0.1), in.texCoord.y);
    
    // Stars
    float n = hash(floor(uv * 50.0).x + floor(uv * 50.0).y * 123.4);
    if (n > 0.99) color += pow(hash(n + t), 10.0);
    
    // Desert Ground Plane (Silhouette)
    float ground = -0.6 + 0.1 * noise(float2(uv.x * 2.0, t * 0.1));
    if (uv.y < ground) {
        color = float3(0.02, 0.01, 0.0);
        // Distant fence posts
        if (fract(uv.x * 10.0) < 0.05) color += 0.02;
    }
    
    // The Beam
    float beamX = sin(t * 0.3) * 0.5;
    float beamDist = abs(uv.x - beamX);
    float beam = exp(-beamDist * 10.0) * smoothstep(-1.0, ground + 1.5, uv.y);
    color += float3(0.2, 1.0, 0.3) * beam * 0.4;
    
    // UFO Raymarch
    float3 ro = float3(0, 1.5, 3);
    float3 rd = normalize(float3(uv.x - beamX, uv.y - 1.2, -1.5));
    float d = 0.0, t_dist = 0.0;
    for(int i=0; i<40; i++) {
        d = ufoSDF(ro + rd * t_dist - float3(beamX, 1.2, 0), t);
        if(d < 0.01 || t_dist > 5.0) break;
        t_dist += d;
    }
    
    if(t_dist < 5.0) {
        float3 p = ro + rd * t_dist;
        color = mix(color, float3(0.5, 0.5, 0.6), 0.8);
        // Lights on UFO
        if(sin(atan2(p.z, p.x) * 10.0 + t * 5.0) > 0.0) {
            color += float3(0.0, 1.0, 0.5) * 0.5;
        }
    }
    
    // "RESTRICTED AREA" Scanline style text effect (simplified)
    if (uv.y > 0.7 && uv.y < 0.75 && abs(uv.x) < 0.8) {
        float flicker = step(0.5, sin(t * 20.0));
        color += float3(1.0, 0.0, 0.0) * flicker * 0.2;
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
