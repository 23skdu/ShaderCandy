#include "base/common.glsl"

// astra_fractal - Mandelbox fractal tunnel with psychedelic color shifts

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    // Dynamic zoom
    float zoomPhase = sin(t * 0.3) * 0.5 + 0.5;
    float zoom = 1.0 + zoomPhase * 3.0;
    vec2 zp = p * zoom;
    
    vec3 color = vec3(0.0);
    float glow = 0.0;
    
    // Simplified Mandelbox fractal iteration
    vec2 z = zp;
    float dr = 1.0;
    float scale = 2.6 + 0.3 * sin(t * 0.5);
    
    for (int i = 0; i < 12; i++) {
        // Box fold
        z = clamp(z, -1.0, 1.0) * 2.0 - z;
        
        // Sphere fold
        float r2 = dot(z, z);
        if (r2 < 0.5) {
            z *= 2.0;
            dr *= 2.0;
        } else if (r2 < 1.0) {
            z *= 1.0 / r2;
            dr *= 1.0 / r2;
        }
        
        z = scale * z + zp;
        dr = dr * abs(scale) + 1.0;
        
        // Accumulate glow
        glow += 0.01 / (1.0 + length(z) * 5.0);
    }
    
    float d = length(z) / abs(dr);
    
    // Color based on iterations and position
    if (d < 0.5) {
        float hue1 = fract(d * 0.5 + t * 0.15);
        float hue2 = fract(t * 0.2 + z.y * 0.2);
        vec3 col1 = hsv2rgb(vec3(hue1, 0.9, 1.0));
        vec3 col2 = hsv2rgb(vec3(hue2, 0.8, 0.9));
        color = mix(col1, col2, sin(d * 10.0) * 0.5 + 0.5);
    }
    
    // Add glow
    vec3 glowColor = hsv2rgb(vec3(fract(t * 0.2 + d * 0.1), 0.9, 1.0));
    color += glow * glowColor * 0.2;
    
    // Starfield background
    if (d > 0.5) {
        color = vec3(0.02, 0.0, 0.08);
        float star = step(0.97, fract(sin(dot(floor(zp * 20.0), vec2(12.9898, 78.233))) * 43758.5453));
        color += hsv2rgb(vec3(fract(sin(dot(zp, vec2(12.9898, 78.233))) * 43758.5453), 0.8, 1.0)) * star * 0.5;
    }
    
    // Chromatic aberration effect
    color.r += (color.r - 0.5) * 0.1 * zoomPhase;
    color.b += (color.b - 0.5) * -0.1 * zoomPhase;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.3;
    
    color *= intensity * 1.2;
    return vec4(color, alpha);
}