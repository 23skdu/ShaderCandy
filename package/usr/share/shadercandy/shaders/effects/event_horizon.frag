#include "base/common.glsl"

// event_horizon - Black hole singularity with gravitational lensing

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Distort space (gravitational lensing)
    float r = length(p);
    float distortion = 0.2 / (r + 0.01);
    vec2 rayUV = p * (1.0 + distortion);
    
    // Background Stars
    vec3 color = vec3(0.0);
    float stars = pow(noise(rayUV * 20.0), 15.0) * 2.0;
    color += stars * vec3(0.8, 0.9, 1.0);
    
    // Accretion Disk (simplified 2D version)
    float angle = atan(p.y, p.x);
    float dist = r;
    
    if (dist > 0.4 && dist < 1.5) {
        float f = noise(vec2(dist * 5.0 + t * 0.2, angle * 2.0 + t * 0.1));
        float density = smoothstep(1.5, 0.6, dist) * smoothstep(0.3, 0.6, dist);
        vec3 diskColor = mix(vec3(1.0, 0.4, 0.1), vec3(1.0, 0.8, 0.5), f);
        color += diskColor * density * (0.5 + 0.5 * f);
    }
    
    // The Singularity (Event Horizon)
    float horizon = smoothstep(0.35, 0.34, r);
    color *= (1.0 - horizon);
    
    // Photon Ring
    float ring = exp(-abs(r - 0.36) * 50.0);
    color += vec3(1.0, 0.9, 0.8) * ring;
    
    // Bloom/Glow
    float glow = exp(-r * 2.0);
    color += vec3(0.2, 0.1, 0.4) * glow * 0.5;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.3;
    
    color *= intensity;
    return vec4(color, alpha);
}