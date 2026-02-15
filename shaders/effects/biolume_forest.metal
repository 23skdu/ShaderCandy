#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  biolume_forest.metal
//  ShaderCandy
//
//  Organic glowing mushrooms, trees, and vines in a dark void
//

using namespace ShaderUtils;

float treeSDF(float3 p, float t, float height, float thickness) {
    // Tree trunk
    float3 tp = p;
    tp.y -= height * 0.5;
    float trunk = length(tp.xz) - thickness * (1.0 - smoothstep(0.0, height, p.y));
    trunk = max(trunk, abs(p.y - height * 0.5) - height * 0.5);
    
    // Branches
    float branches = 1e10;
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float branchY = height * 0.3 + fi * height * 0.25;
        float3 branchP = p - float3(0.0, branchY, 0.0);
        
        // Rotate branches
        float angle = fi * 2.094 + t * 0.1;
        float2 rotXZ = float2(
            branchP.x * cos(angle) - branchP.z * sin(angle),
            branchP.x * sin(angle) + branchP.z * cos(angle)
        );
        branchP.x = rotXZ.x;
        branchP.z = rotXZ.y;
        
        float branch = length(branchP - float3(0.3 + fi * 0.1, 0.0, 0.0)) - thickness * 0.6;
        branches = min(branches, branch);
    }
    
    return min(trunk, branches);
}

float mushroomSDF(float3 p, float3 center, float scale, float t) {
    float3 q = (p - center) / scale;
    
    // Mushroom stalk
    float stalk = length(q.xz) - 0.2 * (1.0 - exp(-q.y * 2.0));
    stalk = max(stalk, q.y - 1.5);
    stalk = max(stalk, -q.y);
    
    // Mushroom cap
    float cap = length(float3(q.x, q.y - 1.5, q.z)) - 0.8;
    cap = max(cap, -(length(float3(q.x, q.y - 1.3, q.z)) - 0.75));
    cap = max(cap, q.y - 1.6);
    
    return min(stalk, cap) * scale;
}

float forestSDF(float3 p, float t) {
    float d = 1e10;
    
    // Multiple mushroom clusters
    for(int i = 0; i < 6; i++) {
        float fi = float(i);
        float3 offset = float3(
            sin(fi * 1.2 + t * 0.05) * 3.0,
            0.0,
            cos(fi * 0.8 + t * 0.07) * 3.0
        );
        
        float3 gridPos = p - offset;
        gridPos.xz = mod(gridPos.xz, 6.0) - 3.0;
        
        float scale = 0.5 + 0.3 * sin(fi * 2.0);
        float mushroom = mushroomSDF(gridPos, float3(0.0, 0.0, 0.0), scale, t);
        d = min(d, mushroom);
    }
    
    // Add trees
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float3 treeOffset = float3(
            cos(fi * 1.5 + t * 0.03) * 4.0,
            0.0,
            sin(fi * 1.1 + t * 0.04) * 4.0
        );
        
        float3 treePos = p - treeOffset;
        treePos.xz = mod(treePos.xz, 8.0) - 4.0;
        
        float tree = treeSDF(treePos, t, 2.0 + fi * 0.5, 0.15 + fi * 0.02);
        d = min(d, tree);
    }
    
    // Ground with gentle undulation
    float ground = p.y + 0.2 * snoise(p.xz * 0.3 + t * 0.1);
    d = min(d, ground);
    
    // Hanging vines
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float3 vinePos = p;
        vinePos.x -= sin(fi * 2.0) * 2.0;
        vinePos.z -= cos(fi * 1.5) * 2.0;
        vinePos.xz = mod(vinePos.xz, 5.0) - 2.5;
        
        float vineWave = sin(vinePos.y * 3.0 + t + fi) * 0.1;
        float vine = length(float2(vinePos.x + vineWave, vinePos.z)) - 0.05;
        vine = max(vine, vinePos.y - 3.0);
        vine = max(vine, -vinePos.y);
        
        d = min(d, vine);
    }
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Camera with slow x-axis rotation
    float camAngle = t * 0.1;
    float3 ro = float3(
        4.0 * sin(camAngle),
        1.5 + 0.5 * cos(t * 0.1),
        t * 1.2
    );
    
    float3 rd = normalize(float3(uv, 1.2));
    
    // Apply slow x-axis rotation
    float3x3 rotX = float3x3(
        1, 0, 0,
        0, cos(t * 0.05), -sin(t * 0.05),
        0, sin(t * 0.05), cos(t * 0.05)
    );
    rd = rotX * rotY(camAngle * 0.3) * rd;
    
    float td = 0.0, d;
    float glow = 0.0;
    float3 accumulatedColor = float3(0.0);
    
    // Enhanced raymarching with glow accumulation
    for (int i = 0; i < 100; i++) {
        float3 p = ro + rd * td;
        d = forestSDF(p, t);
        
        // Glow from bioluminescent elements
        float glowStrength = 0.015 / (1.0 + d * 15.0);
        float3 glowCol = hsv2rgb(float3(
            0.5 + 0.3 * sin(p.x * 0.5 + t * 0.5),
            0.8,
            1.0
        ));
        accumulatedColor += glowCol * glowStrength * exp(-td * 0.1);
        
        if (d < 0.001 || td > 25.0) break;
        td += d * 0.7;
    }
    
    float3 color = float3(0.0);
    if (td < 25.0) {
        float3 p = ro + rd * td;
        
        // Calculate normal for lighting
        float2 e = float2(0.001, 0.0);
        float3 normal = normalize(float3(
            forestSDF(p + e.xyy, t) - forestSDF(p - e.xyy, t),
            forestSDF(p + e.yxy, t) - forestSDF(p - e.yxy, t),
            forestSDF(p + e.yyx, t) - forestSDF(p - e.yyx, t)
        ));
        
        // Multiple light sources for depth
        float3 light1 = normalize(float3(1.0, 2.0, -1.0));
        float3 light2 = normalize(float3(-1.0, 1.5, 1.0));
        
        float diff1 = max(0.0, dot(normal, light1));
        float diff2 = max(0.0, dot(normal, light2)) * 0.5;
        
        // Color based on position and type
        float hue = 0.4 + 0.3 * sin(p.x * 0.3 + t * 0.3);
        float3 baseColor = hsv2rgb(float3(hue, 0.7, 0.9));
        
        color = baseColor * (diff1 + diff2 + 0.2);
        color *= exp(-td * 0.08);
    }
    
    // Add accumulated glow
    color += accumulatedColor;
    
    // Atmospheric fog
    float3 fogColor = hsv2rgb(float3(0.6, 0.5, 0.05));
    color = mix(color, fogColor, 1.0 - exp(-td * 0.12));
    
    // Fireflies/particles
    for(int i = 0; i < 10; i++) {
        float fi = float(i);
        float3 fireflyPos = float3(
            sin(t * 0.5 + fi * 2.0) * 3.0,
            1.0 + cos(t * 0.3 + fi * 1.5) * 1.5,
            ro.z + cos(t * 0.4 + fi) * 3.0
        );
        
        float dist = length(ro + rd * td - fireflyPos);
        float firefly = exp(-dist * 2.0) * (0.5 + 0.5 * sin(t * 5.0 + fi * 3.0));
        color += hsv2rgb(float3(0.25 + fi * 0.05, 0.9, 1.0)) * firefly * 0.3;
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
