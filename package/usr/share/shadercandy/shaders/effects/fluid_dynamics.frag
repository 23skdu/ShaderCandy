// Shader Metadata Example
// This demonstrates how to embed configuration in shader comments

/*
@name Fluid Dynamics
@description Real-time fluid simulation using Navier-Stokes equations
@category Nature
@tags fluid, simulation, physics, blue
@quality 0.8
@audio true
@hdr false

@parameter viscosity
@type float
@range 0.001 0.1
@default 0.01
@description Controls fluid thickness

@parameter colorShift
@type float
@range 0.0 1.0
@default 0.5
@description Color cycling speed

@parameter turbulence
@type float
@range 0.0 2.0
@default 1.0
@description Amount of chaotic motion

@parameter palette
@type choice
@choices Ocean, Fire, Aurora, Grayscale
@default Ocean
@description Color palette selection
*/

#version 450 core

#include "../base/common.glsl"

// Parameters (set by configuration system)
uniform float viscosity = 0.01;
uniform float colorShift = 0.5;
uniform float turbulence = 1.0;
uniform int palette = 0;  // 0=Ocean, 1=Fire, 2=Aurora, 3=Grayscale

// Fluid simulation functions
vec2 fluidVelocity(vec2 uv, float t) {
    vec2 v = vec2(0.0);
    
    // Multiple octaves of flow
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float scale = pow(2.0, fi);
        
        v += vec2(
            snoise(vec3(uv * scale, t * 0.1 * turbulence + fi)),
            snoise(vec3(uv * scale + 100.0, t * 0.1 * turbulence + fi))
        ) / scale;
    }
    
    return v * turbulence;
}

// Color palettes
vec3 getPalette(float t, int palette) {
    if (palette == 0) {  // Ocean
        return mix(
            vec3(0.0, 0.1, 0.3),
            vec3(0.0, 0.8, 1.0),
            smoothstep(0.0, 1.0, t)
        );
    } else if (palette == 1) {  // Fire
        return mix(
            vec3(1.0, 0.0, 0.0),
            vec3(1.0, 1.0, 0.0),
            smoothstep(0.0, 1.0, t)
        );
    } else if (palette == 2) {  // Aurora
        return mix(
            vec3(0.0, 0.3, 0.1),
            vec3(0.5, 1.0, 0.7),
            smoothstep(0.0, 1.0, t)
        );
    } else {  // Grayscale
        return vec3(t);
    }
}

vec4 effect_main(vec2 centered, vec2 uv) {
    // Time with viscosity adjustment
    float t = time * (1.0 - viscosity * 10.0);
    
    // Get fluid velocity at this point
    vec2 vel = fluidVelocity(uv, t);
    
    // Advect coordinates
    vec2 advectedUV = uv - vel * viscosity;
    
    // Calculate curl (vorticity)
    float curl = snoise(vec3(advectedUV * 3.0, t)) * 
                 snoise(vec3(advectedUV * 5.0 + 50.0, t * 0.5));
    
    // Color based on velocity magnitude and curl
    float intensity = length(vel) * 0.5 + abs(curl) * 0.5;
    intensity = clamp(intensity, 0.0, 1.0);
    
    // Apply color shift
    float hue = intensity + colorShift * time * 0.1;
    hue = fract(hue);
    
    vec3 color = getPalette(hue, palette);
    
    // Add turbulence detail
    float detail = snoise(vec3(uv * 20.0, t * 2.0));
    color *= 0.9 + detail * 0.1 * turbulence;
    
    // Vignette
    color *= 1.0 - length(centered) * 0.3;
    
    return vec4(color, 1.0);
}
