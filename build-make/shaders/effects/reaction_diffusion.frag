#version 450 core

#include "../base/common.glsl"

// Reaction-Diffusion (Gray-Scott model) - Render pass
// Requires two-pass setup with ping-pong buffers

uniform sampler2D rdState;  // Previous frame state (RG = chemical concentrations)

// Parameters for Gray-Scott reaction
const float F = 0.0545;  // Feed rate
const float K = 0.062;   // Kill rate
const float Du = 0.2097; // Diffusion rate U
const float Dv = 0.105;  // Diffusion rate V

vec4 effect_main(vec2 centered, vec2 uv) {
    vec2 texel = 1.0 / resolution;
    
    // Sample current state
    vec2 state = texture(rdState, uv).rg;
    float u = state.r;
    float v = state.g;
    
    // Laplacian (9-point stencil for better quality)
    vec2 laplacian = 
        texture(rdState, uv + vec2(-1,  0) * texel).rg * 0.2 +
        texture(rdState, uv + vec2( 1,  0) * texel).rg * 0.2 +
        texture(rdState, uv + vec2( 0, -1) * texel).rg * 0.2 +
        texture(rdState, uv + vec2( 0,  1) * texel).rg * 0.2 +
        texture(rdState, uv + vec2(-1, -1) * texel).rg * 0.05 +
        texture(rdState, uv + vec2(-1,  1) * texel).rg * 0.05 +
        texture(rdState, uv + vec2( 1, -1) * texel).rg * 0.05 +
        texture(rdState, uv + vec2( 1,  1) * texel).rg * 0.05 -
        state;
    
    // Gray-Scott reaction
    float reaction = u * v * v;
    float du = Du * laplacian.r - reaction + F * (1.0 - u);
    float dv = Dv * laplacian.g + reaction - (F + K) * v;
    
    // Update with time step
    float dt = 1.0;
    u += du * dt;
    v += dv * dt;
    
    // Clamp values
    u = clamp(u, 0.0, 1.0);
    v = clamp(v, 0.0, 1.0);
    
    // Color mapping - create beautiful organic patterns
    vec3 color1 = vec3(0.0, 0.0, 0.2);  // Dark blue
    vec3 color2 = vec3(0.0, 0.4, 0.8);  // Blue
    vec3 color3 = vec3(0.0, 0.8, 0.6);  // Teal
    vec3 color4 = vec3(1.0, 0.9, 0.3);  // Yellow
    
    // Mix colors based on chemical concentrations
    float t = u * 2.0;
    vec3 color = mix(color1, color2, smoothstep(0.0, 0.3, t));
    color = mix(color, color3, smoothstep(0.3, 0.6, t));
    color = mix(color, color4, smoothstep(0.6, 1.0, t));
    
    // Add some variation based on v
    color += v * vec3(0.3, 0.1, 0.2);
    
    // Add pulsing glow
    float glow = sin(time * 0.5) * 0.1 + 0.9;
    color *= glow;
    
    return vec4(color, 1.0);
}
