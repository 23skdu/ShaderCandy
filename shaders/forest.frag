#version 450 core

#include "base/common.glsl"

// Forest - Forest scene with trees

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Tree shape
float tree(vec2 p, float height, float width) {
    float d = 100.0;
    
    // Trunk
    float trunk = max(abs(p.x) - width * 0.1, abs(p.y - height * 0.3) - height * 0.3);
    
    // Tree layers (triangles)
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float layerY = height * (0.2 + fi * 0.25);
        float layerWidth = width * (1.0 - fi * 0.2);
        float layerHeight = height * 0.3;
        
        vec2 layerP = p - vec2(0.0, layerY);
        float layer = max(abs(layerP.x) - (1.0 - layerP.y / layerHeight) * layerWidth * 0.5,
                         layerP.y - layerHeight);
        layer = max(layer, -layerP.y);
        
        d = min(d, layer);
    }
    
    return min(d, trunk);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.05;
    vec2 p = centered;
    
    // Sky gradient
    vec3 col = mix(vec3(0.3, 0.6, 0.9), vec3(0.6, 0.8, 1.0), uv.y);
    
    // Sun
    vec2 sunPos = vec2(0.6, 0.7);
    float sun = length(uv - sunPos);
    vec3 sunCol = vec3(1.0, 0.9, 0.6);
    col += sunCol * smoothstep(0.1, 0.0, sun);
    col += sunCol * 0.3 * smoothstep(0.2, 0.0, sun);
    
    // Clouds
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 cloudPos = p + vec2(t * 0.1 + fi * 0.5, 0.3 + fi * 0.1);
        cloudPos.x = mod(cloudPos.x + 2.0, 4.0) - 2.0;
        
        float cloud = 0.0;
        cloud += smoothstep(0.2, 0.0, length(cloudPos));
        cloud += smoothstep(0.15, 0.0, length(cloudPos + vec2(0.15, 0.0)));
        cloud += smoothstep(0.15, 0.0, length(cloudPos + vec2(-0.15, 0.0)));
        
        col = mix(col, vec3(1.0, 1.0, 0.95), cloud * 0.7);
    }
    
    // Ground
    float ground = -0.4 + sin(p.x * 2.0) * 0.05;
    vec3 groundCol = vec3(0.1, 0.4, 0.15);
    col = mix(groundCol, col, step(ground, p.y));
    
    // Trees
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float treeX = -0.7 + fi * 0.2 + sin(fi * 3.0) * 0.1;
        float treeY = ground;
        float treeHeight = 0.4 + sin(fi * 5.0) * 0.1;
        
        vec2 treeP = p - vec2(treeX, treeY + treeHeight * 0.5);
        float treeDist = tree(treeP, treeHeight, 0.3);
        
        vec3 treeCol = mix(vec3(0.1, 0.3, 0.1), vec3(0.05, 0.2, 0.05), 
                          smoothstep(0.0, treeHeight, treeP.y + treeHeight * 0.5));
        
        col = mix(treeCol, col, smoothstep(0.0, 0.01, treeDist));
    }
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
