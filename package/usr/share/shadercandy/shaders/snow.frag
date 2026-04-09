#version 450 core

#include "base/common.glsl"

// Snow - Falling snow effect

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    vec2 p = centered;
    
    // Winter sky
    vec3 col = mix(vec3(0.3, 0.4, 0.5), vec3(0.5, 0.6, 0.7), uv.y);
    
    // Snowflakes
    float snow = 0.0;
    for(int i = 0; i < 60; i++) {
        float fi = float(i);
        
        // Snowflake position
        vec2 snowPos = vec2(
            mod(fi * 0.7 + t * (0.1 + fi * 0.002) + sin(t + fi) * 0.1, 3.0) - 1.5,
            mod(fi * 0.4 - t * (0.3 + fi * 0.01), 2.0) - 1.0
        );
        
        // Snowflake size varies
        float size = 0.01 + hash(fi) * 0.02;
        
        // Distance to snowflake
        float dist = length(p - snowPos);
        
        // Snowflake glow
        snow += smoothstep(size, 0.0, dist);
    }
    
    // Snow color
    vec3 snowCol = vec3(0.95, 0.98, 1.0);
    col += snowCol * snow * 0.5;
    
    // Snow accumulation at bottom
    if(p.y < -0.7) {
        float ground = -0.8 + sin(p.x * 3.0) * 0.05;
        vec3 snowGround = vec3(0.95, 0.95, 1.0);
        col = mix(col, snowGround, smoothstep(ground, ground + 0.1, p.y));
    }
    
    // Trees in background
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float treeX = -0.8 + fi * 0.4;
        
        // Simple tree shape
        vec2 treeP = p - vec2(treeX, -0.5);
        float tree = max(abs(treeP.x) - (0.3 - treeP.y) * 0.2, abs(treeP.y + 0.2) - 0.3);
        
        vec3 treeCol = vec3(0.1, 0.15, 0.1);
        col = mix(treeCol, col, smoothstep(0.0, 0.01, tree));
        
        // Snow on tree
        float snowOnTree = smoothstep(0.0, 0.05, tree) * smoothstep(0.1, 0.0, tree);
        col = mix(col, snowCol, snowOnTree * 0.5);
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
