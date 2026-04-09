#include "base/common.glsl"

// neural_nexus - Futuristic neural network and data stream

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
    
    vec3 color = vec3(0.01, 0.0, 0.05);
    
    // Grid/Nexus
    vec2 gv = fract(p * 5.0) - 0.5;
    vec2 id = floor(p * 5.0);
    
    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 offs = vec2(float(x), float(y));
            vec2 nid = id + offs;
            
            // Pseudo-random position
            float h1 = fract(sin(dot(nid, vec2(127.1, 311.7))) * 43758.5453);
            float h2 = fract(sin(dot(nid, vec2(269.5, 183.3))) * 43758.5453);
            vec2 hp = vec2(h1, h2);
            hp = 0.5 * sin(t + hp * 6.28);
            
            // Connection lines
            vec2 diff = (offs + hp) - gv;
            float d = length(diff);
            float line = smoothstep(0.02, 0.01, d);
            
            // Node points
            float node = smoothstep(0.05, 0.03, length(gv - (offs + hp)));
            
            // Color based on node position
            vec3 nodeColor = hsv2rgb(vec3(h1 + t * 0.1, 0.9, 1.0));
            color += nodeColor * line * 0.4;
            color += nodeColor * node * 0.6;
        }
    }
    
    // Pulsing glow
    float pulse = 0.5 + 0.5 * sin(t * 2.0);
    color *= 0.8 + pulse * 0.2;
    
    // Data stream effect
    float stream = fract(p.y * 20.0 - t * 3.0);
    stream = smoothstep(0.0, 0.1, stream) * smoothstep(0.2, 0.1, stream);
    color += vec3(0.0, 0.5, 1.0) * stream * 0.1;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.5;
    
    color *= intensity;
    return vec4(color, alpha);
}