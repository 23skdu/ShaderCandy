#version 450 core

#include "base/common.glsl"

// Japanese - Japanese-themed scene with sakura

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Cherry blossom petal shape
float petal(vec2 p) {
    p.y -= 0.1;
    float d = length(p) - 0.15;
    // Notch at top
    float notch = smoothstep(0.02, 0.0, abs(p.x)) * smoothstep(0.0, 0.05, p.y);
    d += notch * 0.1;
    return d;
}

// Torii gate
float torii(vec2 p) {
    float d = 100.0;
    
    // Vertical posts
    float leftPost = max(abs(p.x + 0.3) - 0.04, abs(p.y) - 0.4);
    float rightPost = max(abs(p.x - 0.3) - 0.04, abs(p.y) - 0.4);
    
    // Top lintel
    float topLintel = max(abs(p.y - 0.35) - 0.05, abs(p.x) - 0.45);
    
    // Lower lintel
    float lowerLintel = max(abs(p.y - 0.15) - 0.04, abs(p.x) - 0.38);
    
    d = min(min(leftPost, rightPost), min(topLintel, lowerLintel));
    
    return d;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    vec2 p = centered;
    
    // Sky gradient - sunset
    vec3 col = mix(vec3(0.9, 0.6, 0.4), vec3(0.4, 0.3, 0.6), uv.y);
    
    // Sun
    vec2 sunPos = vec2(0.5, 0.6);
    float sun = length(uv - sunPos);
    col += vec3(1.0, 0.8, 0.5) * smoothstep(0.15, 0.0, sun);
    
    // Mountains (Mount Fuji style)
    float mountain1 = -0.3 + abs(p.x + 0.2) * 0.8;
    float mountain2 = -0.2 + abs(p.x - 0.3) * 0.5;
    float mtn = min(mountain1, mountain2);
    
    vec3 mtnCol1 = vec3(0.3, 0.3, 0.4);
    vec3 mtnCol2 = vec3(0.5, 0.4, 0.5);
    col = mix(col, mtnCol1, 1.0 - smoothstep(-0.02, 0.02, p.y - mtn));
    col = mix(col, mtnCol2, 1.0 - smoothstep(-0.02, 0.02, p.y - mountain2));
    
    // Snow cap on Fuji
    float snow = -0.1 + abs(p.x + 0.2) * 0.3;
    if(p.y > mountain1 && p.y < snow) {
        col = mix(col, vec3(1.0), 0.8);
    }
    
    // Ground
    float ground = -0.5;
    col = mix(vec3(0.2, 0.3, 0.2), col, step(ground, p.y));
    
    // Torii gate
    vec2 toriiP = p - vec2(-0.4, -0.2);
    float toriiDist = torii(toriiP);
    vec3 toriiCol = vec3(0.8, 0.1, 0.1);
    col = mix(toriiCol, col, smoothstep(0.0, 0.01, toriiDist));
    
    // Falling sakura petals
    for(int i = 0; i < 30; i++) {
        float fi = float(i);
        
        // Petal position
        vec2 petalPos = vec2(
            mod(fi * 0.3 + t * (0.2 + fi * 0.01) + sin(t + fi) * 0.1, 2.0) - 1.0,
            mod(fi * 0.2 - t * 0.1 + fi * 0.05, 1.5) - 0.5
        );
        
        // Petal rotation
        float petalRot = t + fi;
        vec2 petalUV = (p - petalPos) * rot(petalRot);
        
        float petalDist = petal(petalUV * 3.0);
        float petalGlow = smoothstep(0.05, 0.0, petalDist);
        
        // Sakura pink
        vec3 petalCol = vec3(1.0, 0.7, 0.75);
        col = mix(col, petalCol, petalGlow * 0.8);
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
