#version 450 core

#include "base/common.glsl"

// Newton - Newton fractal visualization

// Complex square
vec2 cSqr(vec2 z) {
    return vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

// Complex cube
vec2 cCube(vec2 z) {
    return vec2(z.x * z.x * z.x - 3.0 * z.x * z.y * z.y, 
                3.0 * z.x * z.x * z.y - z.y * z.y * z.y);
}

// Complex division
vec2 cDiv(vec2 a, vec2 b) {
    float denom = b.x * b.x + b.y * b.y;
    return vec2((a.x * b.x + a.y * b.y) / denom, 
                (a.y * b.x - a.x * b.y) / denom);
}

// Newton iteration for z^3 - 1 = 0
// Roots: 1, -0.5 + 0.866i, -0.5 - 0.866i
vec3 newton(vec2 z, float t) {
    int iter = 0;
    vec2 root = vec2(0.0);
    
    for(int i = 0; i < 30; i++) {
        vec2 z2 = cSqr(z);
        vec2 z3 = cCube(z);
        
        // f(z) = z^3 - 1
        vec2 fz = z3 - vec2(1.0, 0.0);
        
        // f'(z) = 3z^2
        vec2 dfz = 3.0 * z2;
        
        // Newton: z = z - f(z)/f'(z)
        z = z - cDiv(fz, dfz);
        
        iter++;
        
        // Check convergence to roots
        float d1 = length(z - vec2(1.0, 0.0));
        float d2 = length(z - vec2(-0.5, 0.866));
        float d3 = length(z - vec2(-0.5, -0.866));
        
        if(d1 < 0.001) { root = vec2(1.0, 0.0); break; }
        if(d2 < 0.001) { root = vec2(2.0, 0.0); break; }
        if(d3 < 0.001) { root = vec2(3.0, 0.0); break; }
    }
    
    return vec3(root, float(iter));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    
    // Scale and position
    vec2 c = centered * 2.5;
    
    // Animate center
    c += vec2(0.1 * sin(t), 0.1 * cos(t));
    
    vec3 result = newton(c, t);
    float root = result.x;
    float iter = result.z;
    
    vec3 col;
    
    // Color based on which root converged
    if(root < 1.5) {
        // Root 1: Orange/Red
        col = vec3(1.0, 0.5, 0.0);
    } else if(root < 2.5) {
        // Root 2: Green
        col = vec3(0.0, 1.0, 0.5);
    } else {
        // Root 3: Blue/Purple
        col = vec3(0.5, 0.0, 1.0);
    }
    
    // Shade based on iteration count
    float shade = 1.0 - iter / 30.0;
    col *= 0.3 + 0.7 * shade;
    
    // Add some glow
    col += vec3(0.1) * (1.0 - shade);
    
    // Background for non-converged
    if(iter >= 30.0) {
        col = vec3(0.02, 0.02, 0.05);
    }
    
    return vec4(col * intensity, alpha);
}
