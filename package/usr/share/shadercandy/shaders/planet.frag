#version 450 core

#include "base/common.glsl"

// Planet - Planet with atmosphere

// Rotation matrix
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// Planet SDF
float sdSphere(vec2 p, float r) {
    return length(p) - r;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.05;
    vec2 p = centered;
    
    // Space background
    vec3 col = vec3(0.0, 0.0, 0.05);
    
    // Stars
    float stars = pow(noise(uv * 400.0), 30.0);
    col += vec3(0.9, 0.95, 1.0) * stars;
    
    // Planet center
    vec2 planetPos = vec2(0.0, 0.0);
    float planetRadius = 0.4;
    
    float dist = length(p - planetPos);
    
    // Planet
    if(dist < planetRadius) {
        // Planet surface
        vec2 surfaceUV = (p - planetPos) / planetRadius;
        
        // Surface noise for continents
        float continentNoise = snoise(vec3(surfaceUV * 3.0 + t * 0.1, 0.0));
        float continents = smoothstep(0.0, 0.3, continentNoise);
        
        // Ocean color
        vec3 oceanCol = vec3(0.1, 0.3, 0.6);
        // Land color
        vec3 landCol = vec3(0.2, 0.5, 0.2);
        
        vec3 surfaceCol = mix(oceanCol, landCol, continents);
        
        // Clouds
        float cloudNoise = snoise(vec3(surfaceUV * 5.0 + t * 0.2, 10.0));
        float clouds = smoothstep(0.4, 0.6, cloudNoise);
        surfaceCol = mix(surfaceCol, vec3(0.9, 0.95, 1.0), clouds * 0.6);
        
        // Lighting
        vec3 lightDir = normalize(vec3(1.0, 0.5, 0.5));
        vec3 normal = normalize(vec3(surfaceUV, sqrt(1.0 - dot(surfaceUV, surfaceUV))));
        float diff = max(dot(normal, lightDir), 0.0);
        
        // Day/night cycle
        surfaceCol *= (0.1 + 0.9 * diff);
        
        // Atmosphere glow on terminator
        float atmosphere = smoothstep(0.0, 0.3, diff) * (1.0 - smoothstep(0.0, 0.1, diff));
        surfaceCol += vec3(0.3, 0.6, 1.0) * atmosphere * 0.3;
        
        col = surfaceCol;
    }
    
    // Atmosphere halo
    float atmosphereHalo = smoothstep(planetRadius + 0.1, planetRadius, dist) -
                           smoothstep(planetRadius, planetRadius - 0.02, dist);
    col += vec3(0.3, 0.6, 1.0) * atmosphereHalo * 0.5;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
