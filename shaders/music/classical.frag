#include "base/common.glsl"

// classical - Elegant flowing ribbons with gold, ivory tones, and 2D musical notes

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.02, 0.01, 0.05);
    
    // Elegant ribbon curves
    for (float i = 0.0; i < 6.0; i++) {
        float fi = i;
        float offset = fi * 0.4;
        
        vec2 ribbonP = p;
        ribbonP.x += sin(ribbonP.y * 2.0 + t + offset * 2.0) * 0.3;
        ribbonP.x += cos(ribbonP.y * 3.0 + t * 0.5 + offset) * 0.15;
        ribbonP.y += sin(ribbonP.x * 1.5 + t * 0.7 + offset * 1.5) * 0.15;
        
        float ribbonWidth = 0.015 + 0.01 * sin(t + fi);
        float ribbonHeight = 0.25 + 0.05 * sin(t * 0.8 + fi * 2.0);
        
        vec2 ribbonPos = vec2(sin(t * 0.5 + offset) * 0.4, fi * 0.25 - 0.5);
        float ribbon = max(abs(ribbonP.x - ribbonPos.x) - ribbonWidth, 
                          abs(ribbonP.y - ribbonPos.y) - ribbonHeight);
        ribbon = smoothstep(0.03, 0.0, -ribbon);
        
        vec3 ribbonCol1 = mix(vec3(0.95, 0.85, 0.5), vec3(0.9, 0.75, 0.3), sin(t + fi) * 0.5 + 0.5);
        vec3 ribbonCol2 = mix(vec3(1.0, 0.98, 0.9), vec3(0.95, 0.9, 0.8), uv.y);
        vec3 ribbonCol = mix(ribbonCol1, ribbonCol2, fi / 6.0);
        color = mix(color, ribbonCol, ribbon * 0.5);
    }
    
    // 2D Musical Notes floating
    for (float i = 0.0; i < 12.0; i++) {
        float fi = i;
        
        float noteX = sin(t * 0.4 + fi * 0.8) * (1.2 + fi * 0.1);
        float noteY = cos(t * 0.3 + fi * 1.2) * 0.6 + fi * 0.08 - 0.4;
        float noteScale = 0.5 + fi * 0.04;
        
        // Note head (ellipse)
        vec2 noteP = p - vec2(noteX, noteY);
        noteP /= noteScale;
        float noteHead = length(noteP * vec2(1.5, 1.0)) - 0.12;
        
        // Stem
        vec2 stemP = p - vec2(noteX + 0.12 * noteScale, noteY + 0.1 * noteScale);
        stemP /= noteScale;
        float stem = max(abs(stemP.x) - 0.02, abs(stemP.y) - 0.25);
        
        float note = min(smoothstep(0.02, 0.0, -noteHead), smoothstep(0.02, 0.0, -stem));
        
        // Flag for eighth notes
        float noteType = fract(fi * 0.618);
        if (noteType > 0.5) {
            vec2 flagP = p - vec2(noteX + 0.08 * noteScale, noteY + 0.25 * noteScale);
            flagP /= noteScale;
            float flag = smoothstep(0.02, 0.0, length(flagP) - 0.08);
            note = max(note, flag);
        }
        
        vec3 noteCol = noteType > 0.5 ? vec3(1.0, 0.8, 0.3) : vec3(0.95, 0.9, 0.85);
        float sparkle = 0.5 + 0.5 * sin(t * 3.0 + fi * 5.0);
        noteCol += vec3(0.2, 0.15, 0.1) * sparkle;
        
        color += noteCol * note * 0.4;
    }
    
    // Floating treble clefs (simplified 2D)
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        float clefX = -1.2 + fi * 1.2;
        float clefY = sin(t * 0.25 + fi * 2.0) * 0.3;
        
        vec2 clefP = p - vec2(clefX, clefY);
        float clefSpiral = length(clefP) - 0.15 + atan(clefP.y, clefP.x) * 0.02;
        clefSpiral = smoothstep(0.03, 0.0, abs(clefSpiral));
        clefSpiral *= smoothstep(0.3, 0.0, abs(clefP.y));
        
        color += vec3(1.0, 0.85, 0.4) * clefSpiral * 0.3;
    }
    
    // Staff lines
    for (float i = 0.0; i < 5.0; i++) {
        float fi = i;
        float lineY = -0.3 + fi * 0.15;
        float line = smoothstep(0.01, 0.0, abs(p.y - lineY) - 0.002);
        color = mix(color, vec3(0.3, 0.25, 0.2), line * 0.3);
    }
    
    // Vignette and glow
    float vignette = 1.0 - length(p) * 0.4;
    color += vec3(0.08, 0.06, 0.1) * vignette;
    
    // Audio reactivity
    float bassPulse = 1.0 + bass * 0.3 * sin(t * 2.0);
    color *= bassPulse;
    
    float trebleSparkle = random(uv * 100.0 + floor(t * 10.0));
    trebleSparkle = step(0.98 - treble * 0.05, trebleSparkle);
    color += vec3(1.0, 0.95, 0.8) * trebleSparkle * treble;
    
    float warmth = mid * 0.2;
    color = mix(color, color * vec3(1.1, 0.95, 0.8), warmth);
    
    color *= intensity;
    return vec4(color, alpha);
}