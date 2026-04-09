#include "base/common.glsl"

// liquid_aura - Molten iridescent mirror surface with fluid ripples

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
    
    // Simulate height map for fluid surface
    float h = 0.0;
    float amp = 0.5;
    float freq = 0.8;
    for (int i = 0; i < 4; i++) {
        h += amp * noise(p * freq + t * 0.4);
        amp *= 0.5;
        freq *= 2.1;
    }
    
    // Normal from height (simplified)
    vec2 eps = vec2(0.02, 0.0);
    float hx = noise(p + eps.xy + t * 0.4) - noise(p - eps.xy + t * 0.4);
    float hy = noise(p + eps.yx + t * 0.4) - noise(p - eps.yx + t * 0.4);
    vec3 n = normalize(vec3(hx * 0.5, 1.0, hy * 0.5));
    
    // Reflection direction
    vec3 rd = normalize(vec3(p.x, -1.0, p.y));
    vec3 ref = reflect(rd, n);
    
    // Sky color based on reflection
    vec3 sky = hsv2rgb(vec3(fract(ref.y * 2.0 + t * 0.1), 0.6, 0.9));
    
    // Fresnel
    float fre = pow(1.0 + dot(rd, n), 5.0);
    
    // Iridescent surface color
    vec3 surfaceColor = hsv2rgb(vec3(fract(h + t * 0.2), 0.8, 1.0));
    
    // Mix reflection and surface
    vec3 color = mix(sky * 0.5, surfaceColor, fre);
    
    // Add some caustic-like patterns
    float caustic = pow(noise(p * 5.0 + t), 3.0);
    color += caustic * vec3(0.2, 0.4, 0.6);
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.4;
    color *= vig;
    
    color *= intensity;
    return vec4(color, alpha);
}