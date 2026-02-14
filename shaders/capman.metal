// CapMan 3D - Raymarched Pacman
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

struct Ray {
    float3 origin;
    float3 direction;
};


float map(float3 p, float time, constant Uniforms &uniforms) {
    float d = 1e10;
    
    // Maze floor/walls (simplified 3D grid)
    float2 grid = floor(p.xz * 1.5);
    float h = hash(grid) > 0.7 ? 0.8 : 0.05;
    d = min(d, p.y + h);
    
    // Pacman
    float3 pp = p - float3(uniforms.playerPos.x, 0.3, uniforms.playerPos.y);
    float mouth = 0.5 + 0.5 * sin(time * 10.0);
    float pdist = sdSphere(pp, 0.3);
    // Cut mouth
    float a = atan2(pp.y, pp.x);
    if (abs(a) < mouth * 0.5 && pp.x > 0.0) pdist = max(pdist, -pp.x);
    
    d = min(d, pdist);
    
    // Ghosts
    for (int i = 0; i < 4; i++) {
        float3 gp = p - float3(uniforms.ghostPos[i].x, 0.3 + 0.1 * sin(time * 5.0 + i), uniforms.ghostPos[i].y);
        float gdist = sdSphere(gp, 0.25);
        d = min(d, gdist);
    }
    
    return d;
}

float3 getNormal(float3 p, float time, constant Uniforms &uniforms) {
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + e.xyy, time, uniforms) - map(p - e.xyy, time, uniforms),
        map(p + e.yxy, time, uniforms) - map(p - e.yxy, time, uniforms),
        map(p + e.yyx, time, uniforms) - map(p - e.yyx, time, uniforms)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float3 ro = float3(0.0, 4.0, -4.0);
    float3 rd = normalize(float3(uv, 1.5));
    
    // Rotate camera
    float ang = uniforms.time * 0.1;
    ro.xz = float2(ro.x * cos(ang) - ro.z * sin(ang), ro.x * sin(ang) + ro.z * cos(ang));
    rd.xz = float2(rd.x * cos(ang) - rd.z * sin(ang), rd.x * sin(ang) + rd.z * cos(ang));
    rd = lookAt(ro, float3(0,0,0)) * rd;

    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        float d = map(ro + rd * t, uniforms.time, uniforms);
        if (d < 0.001 || t > 20.0) break;
        t += d;
    }
    
    float3 color = float3(0.05, 0.05, 0.1);
    if (t < 20.0) {
        float3 p = ro + rd * t;
        float3 n = getNormal(p, uniforms.time, uniforms);
        float3 light = normalize(float3(1.0, 2.0, -1.0));
        float diff = max(dot(n, light), 0.0);
        
        // Coloring logic
        float3 baseColor = float3(0.1, 0.1, 0.5); // Walls
        
        // Pacman color
        float3 pp = p - float3(uniforms.playerPos.x, 0.3, uniforms.playerPos.y);
        if (length(pp) < 0.35) baseColor = float3(1.0, 1.0, 0.0);
        
        // Ghost colors
        for (int i = 0; i < 4; i++) {
            float3 gp = p - float3(uniforms.ghostPos[i].x, 0.3 + 0.1 * sin(uniforms.time * 5.0 + i), uniforms.ghostPos[i].y);
            if (length(gp) < 0.3) {
                float3 gCol[4] = {float3(1,0,0), float3(0,1,1), float3(1,0.5,0), float3(1,0.7,0.8)};
                baseColor = gCol[i];
            }
        }
        
        color = baseColor * (diff + 0.2);
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
