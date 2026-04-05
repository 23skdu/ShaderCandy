#include "base/common.glsl"

// audio_ray_tracing - Visual representation of audio ray tracing

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec2 p = uv * 2.0 - 1.0;
    float aspect = resolution.x / resolution.y;
    p.x *= aspect;
    
    vec3 color = vec3(0.0);
    
    // Audio source position (center)
    vec2 sourcePos = vec2(0.0, 0.0);
    
    // Generate audio rays (visual representation)
    for (float i = 0.0; i < 32.0; i++) {
        float fi = i;
        float rayAngle = fi / 32.0 * 6.28318;
        
        // Ray direction from source
        vec2 rayDir = vec2(cos(rayAngle), sin(rayAngle));
        
        // Ray path with audio energy
        for (float dist = 0.0; dist < 2.0; dist += 0.02) {
            vec2 rayPos = sourcePos + rayDir * dist;
            
            // Distance from current pixel
            float d = length(p - rayPos);
            
            // Ray thickness varies with distance
            float thickness = 0.02 * (1.0 - dist * 0.3);
            
            // Energy falloff
            float energy = (1.0 - dist * 0.4) * (0.5 + 0.5 * sin(t * 2.0 + fi));
            
            // Visualize ray
            float ray = smoothstep(thickness, thickness * 0.5, d);
            ray *= energy;
            
            // Frequency-based color (different rays = different frequencies)
            float freq = fi / 32.0;
            vec3 rayColor = hsv2rgb(vec3(freq + t * 0.1, 0.8, 1.0));
            
            color += rayColor * ray * 0.1;
        }
    }
    
    // Audio source (glowing center)
    float sourceGlow = 0.1 / (length(p - sourcePos) + 0.1);
    vec3 sourceColor = vec3(1.0, 0.5, 0.2);
    color += sourceColor * sourceGlow;
    
    // Reflection points (surfaces in the room)
    for (float i = 0.0; i < 6.0; i++) {
        float fi = i;
        float reflectAngle = fi / 6.0 * 6.28318 + t * 0.2;
        float reflectDist = 0.8 + 0.2 * sin(t + fi);
        
        vec2 reflectPos = sourcePos + vec2(cos(reflectAngle), sin(reflectAngle)) * reflectDist;
        
        // Reflection point
        float reflect = smoothstep(0.05, 0.02, length(p - reflectPos));
        
        // Pulsing based on audio
        float pulse = 0.5 + 0.5 * sin(t * 3.0 + fi * 1.5);
        vec3 reflectColor = hsv2rgb(vec3(fi / 6.0, 0.7, 0.8)) * (0.5 + pulse * 0.5);
        
        color += reflectColor * reflect * 0.8;
    }
    
    // Room boundaries
    float roomSize = 1.2;
    float roomDist = max(abs(p.x) - roomSize, abs(p.y) - roomSize * 0.7);
    float room = smoothstep(0.02, 0.0, roomDist);
    color = mix(color, vec3(0.1, 0.15, 0.2), room);
    
    // Acoustic field visualization (subtle background pattern)
    float field = sin(p.x * 10.0 + t) * sin(p.y * 8.0 + t * 0.7);
    field = field * 0.5 + 0.5;
    field *= 0.1;
    color += vec3(0.0, 0.05, 0.1) * field;
    
    // Audio-reactive pulse
    float audioPulse = bass * 0.3 + mid * 0.2 + treble * 0.1;
    color *= (1.0 + audioPulse * 0.5);
    
    color *= intensity;
    return vec4(color, alpha);
}