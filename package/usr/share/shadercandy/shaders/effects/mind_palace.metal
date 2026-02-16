#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  mind_palace.metal
//  ShaderCandy
//
//  Infinite shifting architectural rooms with rotating perspectives,
//  glowing hieroglyphs, and appearing/disappearing cross beams
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
    
    // Cross beams that appear and disappear
    float beams = 1e10;
    
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        // Appear/disappear based on time and position
        float appearPhase = fract(t * 0.2 + fi * 0.25);
        float appear = step(0.3, appearPhase) * step(appearPhase, 0.8);
        
        if(appear > 0.5) {
            // X beams
            float3 beamXP = q - float3(0.0, 0.0, fi - 1.5);
            float beamX = length(beamXP.xy) - 0.08;
            beamX = max(beamX, abs(beamXP.z) - 0.5);
            
            // Y beams
            float3 beamYP = q - float3(fi - 1.5, 0.0, 0.0);
            float beamY = length(beamYP.yz) - 0.08;
            beamY = max(beamY, abs(beamYP.x) - 0.5);
            
            // Diagonal beams
            float3 beamDP = q - float3((fi - 1.5) * 0.7, (fi - 1.5) * 0.7, 0.0);
            float beamD = length(float2(beamDP.x + beamDP.y, beamDP.z)) - 0.06;
            beamD = max(beamD, abs(beamDP.x - beamDP.y) - 0.5);
            
            beams = min(beams, min(beamX, min(beamY, beamD)));
        }
    }
    
    // Floating geometric shapes
    float shapes = 1e10;
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 shapePos = float3(
            sin(t * 0.5 + fi * 2.0) * 1.0,
            cos(t * 0.4 + fi * 1.5) * 1.0,
            sin(t * 0.3 + fi) * 1.0
        );
        
        float3 sP = q - shapePos;
        float shape = sdBox(sP, float3(0.15));
        shapes = min(shapes, shape);
    }
    
    return min(min(box, pillars), min(beams, shapes));
}

// Staircase SDF
float staircaseSDF(float3 p, float t) {
    float stairs = 1e10;
    
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float3 stepPos = float3(
            sin(t * 0.1 + fi * 0.2) * 2.0,
            -1.5 + fi * 0.4,
            cos(t * 0.1 + fi * 0.2) * 2.0
        );
        
        float step = sdBox(p - stepPos, float3(0.8, 0.1, 0.8));
        stairs = min(stairs, step);
    }
    
    return stairs;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Rotating perspectives - camera moves through changing viewpoints
    float viewAngle = t * 0.2;
    float viewHeight = 1.5 + sin(t * 0.3) * 1.0;
    float3 ro = float3(
        sin(viewAngle) * 3.0,
        viewHeight,
        cos(viewAngle) * 3.0 + t * 0.5
    );
    
    // Look at point also rotates
    float3 lookTarget = float3(
        sin(viewAngle * 1.5) * 0.5,
        0.5 + sin(t * 0.4) * 0.5,
        t * 0.5
    );
    
    float3 fwd = normalize(lookTarget - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Additional rotation for perspective shift
    rd = rotX(sin(t * 0.15) * 0.2) * rotY(cos(t * 0.1) * 0.15) * rd;
    
    float td = 0.0, d;
    float3 color = float3(0.0);
    float glow = 0.0;
    
    for (int i = 0; i < 100; i++) {
        float3 p = ro + rd * td;
        d = palaceSDF(p, t);
        
        // Accumulate glow from appearing beams
        glow += 0.008 / (1.0 + d * 15.0);
        
        if (d < 0.001 || td > 25.0) break;
        td += d * 0.7;
    }
    
    if (td < 25.0) {
        float3 p = ro + rd * td;
        float3 n = normalize(float3(
            palaceSDF(p + float3(0.01, 0, 0), t) - palaceSDF(p - float3(0.01, 0, 0), t),
            palaceSDF(p + float3(0, 0.01, 0), t) - palaceSDF(p - float3(0, 0.01, 0), t),
            palaceSDF(p + float3(0, 0, 0.01), t) - palaceSDF(p - float3(0, 0, 0.01), t)
        ));
        
        // Glowing patterns on surfaces
        float patternX = step(0.85, fract(p.x * 2.0 + t * 0.5));
        float patternY = step(0.85, fract(p.y * 2.0 + t * 0.3));
        float patternZ = step(0.85, fract(p.z * 2.0 + t * 0.4));
        float pattern = max(patternX, max(patternY, patternZ));
        
        // Color shifts based on perspective angle
        float hueShift = fract(t * 0.05 + viewAngle * 0.1);
        float3 baseColor = hsv2rgb(float3(hueShift, 0.6, 0.3));
        float3 patternColor = hsv2rgb(float3(fract(hueShift + 0.5), 0.9, 1.0));
        
        color = mix(baseColor, patternColor, pattern);
        
        // Lighting
        float3 lightDir = normalize(float3(1, 2, -1));
        float diff = max(0.2, dot(n, lightDir));
        color *= diff;
        
        // Specular from multiple virtual lights
        for(int i = 0; i < 3; i++) {
            float fi = float(i);
            float3 lightPos = float3(
                sin(t * 0.5 + fi * 2.0) * 3.0,
                2.0 + cos(t * 0.4 + fi),
                cos(t * 0.3 + fi * 1.5) * 3.0
            );
            float3 toLight = normalize(lightPos - p);
            float spec = pow(max(dot(reflect(-toLight, n), -rd), 0.0), 32.0);
            color += hsv2rgb(float3(fract(hueShift + fi * 0.33), 0.8, 1.0)) * spec * 0.3;
        }
    }
    
    // Dynamic glow color
    color += glow * hsv2rgb(float3(fract(t * 0.08 + viewAngle * 0.1), 0.8, 1.0));
    
    // Depth fog with color grading
    float3 fogColor = hsv2rgb(float3(fract(t * 0.03), 0.4, 0.05));
    color = mix(color, fogColor, 1.0 - exp(-td * 0.12));
    
    // Perspective grid lines
    float grid = 0.0;
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float2 gridUV = uv * (2.0 + fi);
        float2 gridFract = fract(gridUV);
        grid += (step(0.95, gridFract.x) + step(0.95, gridFract.y)) * 0.05 / (1.0 + fi);
    }
    color += hsv2rgb(float3(fract(t * 0.1), 0.7, 1.0)) * grid;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
