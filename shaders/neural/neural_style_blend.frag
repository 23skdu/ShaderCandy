#include "base/common.glsl"

// neural_style_blend - Artistic style blend effect with color shifts

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.0);
    
    // Base gradient with artistic style
    float pattern = sin(p.x * 3.0 + t) * cos(p.y * 2.0 + t * 0.7);
    pattern = pattern * 0.5 + 0.5;
    
    // Color palette inspired by neural style transfer
    vec3 style1 = vec3(0.9, 0.4, 0.2);  // Warm orange
    vec3 style2 = vec3(0.2, 0.4, 0.8);  // Cool blue
    vec3 style3 = vec3(0.8, 0.2, 0.5);  // Magenta
    vec3 style4 = vec3(0.3, 0.7, 0.4);  // Green
    
    // Blend between styles based on pattern
    float blend1 = smoothstep(0.3, 0.7, pattern);
    float blend2 = smoothstep(0.4, 0.6, sin(pattern * 3.14159 + t * 0.2));
    float blend3 = smoothstep(0.2, 0.8, length(p) * 0.5);
    
    color = mix(style1, style2, blend1);
    color = mix(color, style3, blend2 * 0.5);
    color = mix(color, style4, blend3 * 0.3);
    
    // Add texture/brush stroke effect
    float brushX = sin(p.x * 20.0 + t * 0.5) * 0.5 + 0.5;
    float brushY = sin(p.y * 15.0 + t * 0.3) * 0.5 + 0.5;
    float brush = brushX * brushY;
    
    color *= 0.8 + brush * 0.4;
    
    // Edge detection for artistic outlines
    float edge = abs(pattern - 0.5) * 2.0;
    edge = smoothstep(0.8, 1.0, edge);
    color = mix(color, vec3(0.1, 0.05, 0.0), edge * 0.5);
    
    // Saturation/contrast adjustment
    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luma), color, 1.2);  // Increase saturation
    
    // Apply contrast
    color = (color - 0.5) * 1.2 + 0.5;
    
    // Vignette
    color *= smoothstep(1.5, 0.3, length(p));
    
    color *= intensity;
    return vec4(color, alpha);
}