#version 450 core

#include "base/common.glsl"

// Alien Landscape - Procedural alien terrain

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Terrain height function
float terrain(vec2 p) {
    float h = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    
    // Layered noise for terrain
    for(int i = 0; i < 5; i++) {
        h += amp * snoise(vec3(p * freq, 0.0));
        amp *= 0.5;
        freq *= 2.0;
    }
    
    return h;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.1;
    vec2 p = centered;
    
    // Sky gradient - alien colors
    vec3 sky = mix(vec3(0.4, 0.1, 0.5), vec3(0.1, 0.0, 0.3), uv.y);
    
    // Stars
    float stars = pow(noise(uv * 300.0), 25.0);
    sky += vec3(1.0) * stars;
    
    // Terrain
    vec2 terrainUV = p;
    terrainUV.x += t * 0.1; // Scroll
    
    float h = terrain(terrainUV);
    
    // Create horizon
    float horizon = -0.2;
    float terrainHeight = horizon + h * 0.4;
    
    vec3 col = sky;
    
    if(p.y < terrainHeight) {
        // Terrain color - alien hues
        vec3 groundCol1 = vec3(0.3, 0.8, 0.2); // Alien green
        vec3 groundCol2 = vec3(0.6, 0.2, 0.6); // Alien purple
        vec3 groundCol3 = vec3(0.8, 0.4, 0.1); // Alien orange
        
        float terrainMix = snoise(vec3(terrainUV * 0.5, 0.0));
        vec3 groundCol = mix(groundCol1, groundCol2, smoothstep(-0.3, 0.3, terrainMix));
        groundCol = mix(groundCol, groundCol3, smoothstep(0.3, 0.6, terrainMix));
        
        // Shading based on height
        float light = 0.5 + 0.5 * h;
        col = groundCol * light;
        
        // Add some alien vegetation glow
        float veg = snoise(vec3(terrainUV * 3.0, t));
        if(veg > 0.6) {
            col += vec3(0.2, 0.8, 0.4) * (veg - 0.6) * 2.0;
        }
    }
    
    // Distant planet/moon
    vec2 moonPos = vec2(0.6, 0.7);
    float moon = length(uv - moonPos);
    if(moon < 0.15) {
        vec3 moonCol = vec3(0.8, 0.9, 1.0);
        float moonSurface = snoise(vec3(uv * 5.0, 0.0));
        moonCol *= 0.8 + 0.2 * moonSurface;
        
        // Crater
        float crater = smoothstep(0.05, 0.02, length(uv - moonPos - vec2(0.03, 0.02)));
        moonCol *= 1.0 - crater * 0.3;
        
        col = mix(col, moonCol, smoothstep(0.15, 0.14, moon));
    }
    
    // Atmospheric haze
    col = mix(col, sky, smoothstep(horizon, horizon + 0.3, p.y));
    
    col *= intensity;
    return vec4(col, alpha);
}
