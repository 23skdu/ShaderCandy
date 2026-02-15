#include "ShaderInterop.h"
#include "../base/utils.metal"


// Classical - Elegant flowing ribbons with gold, ivory tones, and 3D musical notes

#include <metal_stdlib>
using namespace metal;

/* struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float speed;
    float intensity;
    float bass;
    float mid;
    float treble;
}; */

using namespace ShaderUtils;

float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 3D Musical Note SDF
float noteSDF(float3 p, float noteType) {
    float d = 1e10;
    
    // Note head (ellipse)
    float3 headP = p - float3(0.0, -0.15, 0.0);
    float head = length(headP.xz * float2(1.5, 1.0)) - 0.12;
    head = max(head, abs(headP.y) - 0.05);
    
    // Stem
    float3 stemP = p - float3(0.12, 0.1, 0.0);
    float stem = length(stemP.xz) - 0.02;
    stem = max(stem, abs(stemP.y) - 0.25);
    
    d = min(head, stem);
    
    // Flag for eighth notes
    if (noteType > 0.5) {
        float3 flagP = p - float3(0.08, 0.25, 0.0);
        // Curved flag
        float flag = length(flagP - float2(sin(flagP.y * 5.0) * 0.08, 0.0).xyx) - 0.03;
        flag = max(flag, abs(flagP.y) - 0.15);
        flag = max(flag, -flagP.x + 0.05);
        d = min(d, flag);
    }
    
    return d;
}

// Treble clef approximation
float trebleClefSDF(float3 p) {
    float d = 1e10;
    
    // Main spiral body
    float angle = atan2(p.z, p.x);
    float radius = length(p.xz);
    float spiral = radius - (0.15 + angle * 0.02);
    spiral = abs(spiral) - 0.03;
    spiral = max(spiral, abs(p.y) - 0.3);
    
    // Center dot
    float dot = length(p - float3(0.0, -0.2, 0.0)) - 0.05;
    
    return min(spiral, dot);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                            constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * u.speed * 0.3;
    
    float3 col = float3(0.02, 0.01, 0.05);
    
    // Elegant ribbon curves with more depth
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float offset = fi * 0.4;
        
        float2 ribbonP = p;
        // More complex wave motion
        ribbonP.x += sin(ribbonP.y * 2.0 + t + offset * 2.0) * 0.3;
        ribbonP.x += cos(ribbonP.y * 3.0 + t * 0.5 + offset) * 0.15;
        ribbonP.y += sin(ribbonP.x * 1.5 + t * 0.7 + offset * 1.5) * 0.15;
        
        // Ribbon with varying width
        float ribbonWidth = 0.015 + 0.01 * sin(t + fi);
        float ribbonHeight = 0.25 + 0.05 * sin(t * 0.8 + fi * 2.0);
        float ribbon = sdBox(ribbonP - float2(sin(t * 0.5 + offset) * 0.4, fi * 0.25 - 0.5), 
                             float2(ribbonWidth, ribbonHeight));
        ribbon = smoothstep(0.03, 0.0, ribbon);
        
        // Gold to ivory gradient with depth variation
        float3 ribbonCol1 = mix(float3(0.95, 0.85, 0.5), float3(0.9, 0.75, 0.3), sin(t + fi) * 0.5 + 0.5);
        float3 ribbonCol2 = mix(float3(1.0, 0.98, 0.9), float3(0.95, 0.9, 0.8), uv.y);
        float3 ribbonCol = mix(ribbonCol1, ribbonCol2, fi / 6.0);
        col = mix(col, ribbonCol, ribbon * 0.5);
    }
    
    // 3D Musical Notes floating in space
    float3 accumulatedNotes = float3(0.0);
    
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        
        // Note position with 3D movement
        float3 notePos = float3(
            sin(t * 0.4 + fi * 0.8) * (1.2 + fi * 0.1),
            cos(t * 0.3 + fi * 1.2) * 0.6 + fi * 0.08 - 0.4,
            2.0 + sin(t * 0.2 + fi) * 0.5
        );
        
        // Perspective projection
        float perspective = 1.0 / (1.0 + notePos.z * 0.3);
        float2 projP = (p - notePos.xy) * perspective;
        
        // Raymarch the 3D note
        float3 ro = float3(0.0, 0.0, 3.0);
        float3 rd = normalize(float3(projP, -1.0));
        
        float d = 0.0, td = 0.0;
        float noteType = fract(fi * 0.618) > 0.5 ? 1.0 : 0.0;
        
        for (int j = 0; j < 32; j++) {
            float3 pos = ro + rd * td;
            d = noteSDF(pos - float3(0.0, 0.0, notePos.z), noteType);
            if (d < 0.001 || td > 5.0) break;
            td += d;
        }
        
        if (td < 5.0) {
            // Note color based on position and type
            float hue = fract(fi * 0.1 + t * 0.1);
            float3 noteCol;
            if (noteType > 0.5) {
                // Eighth note - amber
                noteCol = float3(1.0, 0.8, 0.3);
            } else {
                // Quarter note - pearl
                noteCol = float3(0.95, 0.9, 0.85);
            }
            
            // Add sparkle effect
            float sparkle = 0.5 + 0.5 * sin(t * 3.0 + fi * 5.0);
            noteCol += float3(0.2, 0.15, 0.1) * sparkle;
            
            accumulatedNotes += noteCol * perspective * 0.15;
        }
    }
    
    col += accumulatedNotes;
    
    // Floating treble clefs
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 clefPos = float3(
            -1.2 + fi * 1.2,
            sin(t * 0.25 + fi * 2.0) * 0.3,
            3.0 + fi * 0.5
        );
        
        float perspective = 1.0 / (1.0 + clefPos.z * 0.3);
        float2 projP = (p - clefPos.xy) * perspective;
        
        float3 ro = float3(0.0, 0.0, 3.0);
        float3 rd = normalize(float3(projP, -1.0));
        
        float d = 0.0, td = 0.0;
        for (int j = 0; j < 32; j++) {
            float3 pos = ro + rd * td;
            d = trebleClefSDF(pos - float3(0.0, 0.0, clefPos.z));
            if (d < 0.001 || td > 5.0) break;
            td += d;
        }
        
        if (td < 5.0) {
            float3 clefCol = float3(1.0, 0.85, 0.4); // Gold
            col += clefCol * perspective * 0.3;
        }
    }
    
    // Staff lines (subtle)
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float lineY = -0.3 + fi * 0.15;
        float line = abs(p.y - lineY) - 0.002;
        line = smoothstep(0.01, 0.0, line);
        col = mix(col, float3(0.3, 0.25, 0.2), line * 0.3);
    }
    
    // Soft ambient glow with depth
    float vignette = 1.0 - length(p) * 0.4;
    col += float3(0.08, 0.06, 0.1) * vignette;
    
    // Audio reactivity
    // Bass creates pulsing glow
    float bassPulse = 1.0 + u.bass * 0.3 * sin(t * 2.0);
    col *= bassPulse;
    
    // Treble adds sparkle particles
    float trebleSparkle = custom_random(uv * 100.0 + floor(t * 10.0));
    trebleSparkle = step(0.98 - u.treble * 0.05, trebleSparkle);
    col += float3(1.0, 0.95, 0.8) * trebleSparkle * u.treble;
    
    // Mid frequencies affect color temperature
    float warmth = u.mid * 0.2;
    col = mix(col, col * float3(1.1, 0.95, 0.8), warmth);
    
    // Final intensity
    col *= u.intensity;
    
    return float4(col, 1.0);
}
