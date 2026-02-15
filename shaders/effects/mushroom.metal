#include "ShaderInterop.h"
#include "../base/utils.metal"

// Mushroom Particle System Shader
// 3D rotating neon rainbow colored mushrooms as particles on fractal background

#include <metal_stdlib>
using namespace metal;
using namespace ShaderUtils;

// SDF for mushroom cap
float sdMushroomCap(float3 p, float scale, float t) {
    // Create a spherical cap with noise for organic effect
    float3 q = p;
    q.y -= 0.5 * scale;
    
    // Add some organic deformation
    float noise = snoise(q * 3.0 + t * 0.5) * 0.2;
    
    float cap = length(q) - (0.8 * scale + noise);
    return cap;
}

// SDF for mushroom stalk
float sdMushroomStalk(float3 p, float scale, float t) {
    // Create a cylindrical stalk with deformation
    float3 q = p;
    q.y -= 0.5 * scale;
    
    // Add some organic deformation to the stalk
    float noise = snoise(q * 2.0 + t * 0.3) * 0.1;
    float radius = 0.1 * scale + noise;
    
    float stalk = length(q.xz) - radius;
    stalk = max(stalk, q.y);
    stalk = max(stalk, -q.y + 1.5 * scale);
    
    return stalk;
}

// Complete mushroom SDF (cap + stalk)
float sdMushroom(float3 p, float3 center, float scale, float t, float rotation) {
    float3 q = (p - center);
    
    // Apply rotation around Y axis
    float c = cos(rotation);
    float s = sin(rotation);
    float3 rotated = float3(q.x * c - q.z * s, q.y, q.x * s + q.z * c);
    
    // Create mushroom with cap and stalk
    float cap = sdMushroomCap(rotated, scale, t);
    float stalk = sdMushroomStalk(rotated, scale, t);
    
    float mushroom = min(cap, stalk);
    
    // Add some color variation
    float color = (1.0 + snoise(center * 2.0 + t)) * 0.5;
    mushroom *= 1.0 + color * 0.5;
    
    return mushroom;
}

// Fractal background with neon glow
float fractalBackground(float3 p, float t) {
    // Multiple noise layers for fractal effect
    float d = 1e10;
    
    // Base noise layer
    float n1 = snoise(p * 0.5 + t * 0.1);
    d = min(d, n1 * 10.0);
    
    // Higher frequency layer
    float n2 = snoise(p * 2.0 + t * 0.2);
    d = min(d, n2 * 5.0);
    
    // Even higher frequency layer
    float n3 = snoise(p * 4.0 + t * 0.3);
    d = min(d, n3 * 2.0);
    
    // Combine into fractal pattern
    float fractal = (n1 + n2 * 0.5 + n3 * 0.25) * 2.0;
    
    // Add glowing effect
    float glow = 0.5 + 0.5 * (1.0 + snoise(p * 1.0)) * 0.3;
    
    return fractal * glow;
}

// Particle system for mushrooms
float particleMushroom(float3 p, float t) {
    float d = 1e10;
    
    // Add multiple rotating mushrooms
    for(int i = 0; i < 40; i++) {
        float fi = float(i);
        
        // Position particles in a circular pattern at different heights
        float angle = fi * 0.5 + t * 0.1;
        float radius = 3.0 + sin(fi * 0.3 + t * 0.1) * 1.5;
        float height = -3.0 + fi * 0.2;
        
        float3 pos = float3(
            sin(angle) * radius,
            height,
            cos(angle) * radius
        );
        
        // Random mushroom size
        float size = 0.3 + 0.4 * (0.5 + 0.5 * sin(fi * 0.4 + t * 0.2));
        
        // Vary rotation
        float rotation = fi * 0.3 + t * 0.2;
        
        float mushroom = sdMushroom(p, pos, size, t, rotation);
        d = min(d, mushroom);
    }
    
    return d;
}

// Main rendering function
float4 renderMushroomScene(float3 p, float t) {
    // Create fractal background
    float bg = fractalBackground(p, t);
    
    // Add particles
    float particles = particleMushroom(p, t);
    
    // Combine background and particles
    float d = min(bg, particles);
    
    // Create color based on distance from scene elements
    float4 color = float4(0.0, 0.0, 0.0, 1.0); // Default black
    
    if(particles < 0.5) {
        // Mushroom colors - neon rainbow effect
        float hue = fmod(t * 0.1 + (p.x + p.y + p.z) * 0.1, 1.0);
        float3 rainbow = float3(
            0.5 + 0.5 * sin(hue * 6.28),
            0.5 + 0.5 * sin(hue * 6.28 + 2.094),
            0.5 + 0.5 * sin(hue * 6.28 + 4.188)
        );
        
        // Make it more neon
        float3 neon = rainbow * 2.0;
        neon = min(neon, 1.0);
        
        // Add glow effect
        color = float4(neon, 1.0);
    } else if(bg < 1.0) {
        // Background colors - neon glow
        float hue = fmod(t * 0.1 + (p.x + p.y + p.z) * 0.05, 1.0);
        float3 bg_color = float3(
            0.5 + 0.5 * sin(hue * 6.28),
            0.5 + 0.5 * sin(hue * 6.28 + 2.094),
            0.5 + 0.5 * sin(hue * 6.28 + 4.188)
        );
        
        // Make it more subtle for background
        float3 bg_neon = bg_color * 0.5;
        bg_neon = min(bg_neon, 1.0);
        
        color = float4(bg_neon, 1.0);
    }
    
    return color;
}

extern "C" {
    fragment float4 fragment_shader(const VertexOut vertex_in [[stage_in]],
                                    constant Uniforms &uniforms [[buffer(0)]]) {
        // Convert to world space
        float3 p = vertex_in.position;
        
        // Add some time offset
        float t = uniforms.time;
        
        // Render the scene
        float4 color = renderMushroomScene(p, t);
        
        return color;
    }
}