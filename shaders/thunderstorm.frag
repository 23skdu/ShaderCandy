#version 450 core

#include "base/common.glsl"

// Thunderstorm - Lightning storm

// Helper function for distance to line segment
float distanceToSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Lightning bolt
float lightning(vec2 p, vec2 start, vec2 end, float seed) {
    float d = 100.0;
    
    vec2 dir = end - start;
    float len = length(dir);
    dir /= len;
    
    // Create jagged path
    float steps = 20.0;
    vec2 prev = start;
    
    for(float i = 1.0; i <= steps; i++) {
        float t = i / steps;
        vec2 pos = mix(start, end, t);
        
        // Add jitter
        float jitter = (hash(seed + i * 1.3) - 0.5) * 0.3 * (1.0 - t);
        pos += vec2(-dir.y, dir.x) * jitter;
        
        // Distance to segment
        float segDist = distanceToSegment(p, prev, pos);
        d = min(d, segDist);
        
        prev = pos;
    }
    
    return d;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    vec2 p = centered;
    
    // Stormy sky
    vec3 col = mix(vec3(0.05, 0.05, 0.1), vec3(0.1, 0.1, 0.15), uv.y);
    
    // Dark clouds
    float clouds = fbm(vec3(p * 3.0, t * 0.2), 5);
    col = mix(col, vec3(0.08, 0.08, 0.12), smoothstep(0.2, 0.6, clouds));
    
    // Lightning
    float lightningIntensity = 0.0;
    
    // Trigger lightning randomly
    if(hash(floor(t * 2.0) * 12.34) > 0.7) {
        float flash = fract(t * 2.0);
        lightningIntensity = exp(-flash * 5.0);
        
        // Multiple bolts
        for(int i = 0; i < 3; i++) {
            float fi = float(i);
            vec2 start = vec2(hash(floor(t * 2.0) + fi * 3.0) * 2.0 - 1.0, 1.0);
            vec2 end = vec2(hash(floor(t * 2.0) + fi * 3.0 + 1.0) * 2.0 - 1.0, -0.5);
            
            float bolt = lightning(p, start, end, floor(t * 2.0) + fi);
            col += vec3(0.9, 0.95, 1.0) * smoothstep(0.05, 0.0, bolt) * lightningIntensity;
        }
    }
    
    // Ambient flash
    col += vec3(0.1, 0.12, 0.15) * lightningIntensity;
    
    // Rain
    float rain = 0.0;
    for(int i = 0; i < 40; i++) {
        float fi = float(i);
        vec2 rainPos = vec2(
            mod(fi * 0.4 + t * 0.5, 3.0) - 1.5,
            mod(fi * 0.3 - t * 1.5, 2.0) - 1.0
        );
        rain += smoothstep(0.02, 0.0, length(p - rainPos));
    }
    col += vec3(0.4, 0.5, 0.6) * rain * 0.2;
    
    // Vignette
    col *= 1.0 - length(centered) * 0.3;
    
    col *= intensity;
    return vec4(col, alpha);
}
