#include "base/common.glsl"

// punk - Raw, aggressive aesthetic with DIY energy

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
    
    // Raw, grungy background
    vec3 color = vec3(0.02, 0.02, 0.03);
    
    // Chaotic noise
    float chaos = noise(p * 5.0 + t);
    chaos += noise(p * 10.0 - t * 0.7) * 0.5;
    chaos += noise(p * 20.0 + t * 1.3) * 0.25;
    
    // Mohawk-style spikes
    for (float i = 0.0; i < 7.0; i++) {
        float fi = i;
        float spikeX = -0.8 + fi * 0.27;
        float spikeH = 0.3 + 0.2 * sin(t * 3.0 + fi);
        float spike = smoothstep(0.1, 0.0, abs(p.x - spikeX)) * 
                      smoothstep(-0.5, spikeH, p.y);
        
        vec3 spikeColor = hsv2rgb(vec3(0.0 + fi * 0.05, 0.9, 1.0));
        color += spikeColor * spike;
    }
    
    // Safety pin lines
    for (float i = 0.0; i < 4.0; i++) {
        float fi = i;
        float pinX = -0.6 + fi * 0.4;
        float pinY = sin(t * 2.0 + fi * 0.5) * 0.3;
        
        float pinDist = length(p - vec2(pinX, pinY));
        float pin = smoothstep(0.03, 0.01, pinDist);
        color += vec3(0.8, 0.8, 0.8) * pin * 0.5;
    }
    
    // X patterns (DIY sticker style)
    for (float i = 0.0; i < 3.0; i++) {
        float fi = i;
        vec2 xPos = vec2(sin(fi * 2.1) * 0.6, cos(fi * 1.7) * 0.4);
        vec2 xP = p - xPos;
        
        float x1 = smoothstep(0.02, 0.0, abs(xP.x + xP.y));
        float x2 = smoothstep(0.02, 0.0, abs(xP.x - xP.y));
        float xMark = max(x1, x2);
        
        vec3 xColor = hsv2rgb(vec3(fi * 0.3, 1.0, 1.0));
        color += xColor * xMark * 0.7;
    }
    
    // Grungy splatters
    float splatter = pow(noise(p * 15.0 + t * 0.5), 4.0);
    color += vec3(0.9, 0.2, 0.1) * splatter * 0.4;
    
    // Random scratches
    float scratch = step(0.7, fract(sin(dot(floor(p * 30.0), vec2(12.9898, 78.233))) * 43758.5453);
    color += vec3(0.5) * scratch * 0.1;
    
    // Vignette
    color *= 1.0 - length(uv - 0.5) * 0.6;
    
    color *= intensity;
    return vec4(color, alpha);
}