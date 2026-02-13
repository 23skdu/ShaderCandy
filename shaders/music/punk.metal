// Punk - Raw, aggressive aesthetic with DIY energy

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float speed;
    float intensity;
    float bass;
    float mid;
    float treble;
};

float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

float noise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

fragment float4 punk_fragment(VertexOut in [[stage_in]],
                              constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.8;
    
    // Chaotic, grungy background
    float3 col = float3(0.02, 0.02, 0.03);
    
    // Static/noise texture
    float staticNoise = random(uv * 500.0 + t * 100.0);
    col += float3(staticNoise * 0.1);
    
    // Jagged diagonal lines (DIY tape effect)
    float2 tapeP = p;
    tapeP += float2(sin(t * 2.0), cos(t * 1.5)) * 0.2;
    
    float tape = abs(sin(tapeP.x * 20.0 + tapeP.y * 15.0 + t * 3.0));
    tape = smoothstep(0.7, 0.9, tape);
    
    // Punk colors - safety orange and black
    float3 tapeCol = float3(1.0, 0.4, 0.0);  // Safety orange
    col = mix(col, tapeCol, tape * 0.6);
    
    // Distorted circles (concert lights)
    float numLights = 5.0;
    for (float i = 0.0; i < numLights; i++) {
        float angle = i * 6.28318 / numLights + t * 0.3;
        float2 lightPos = float2(cos(angle), sin(angle)) * 0.6;
        float dist = length(p - lightPos);
        
        float flicker = random(float2(t + i, i)) * 0.5 + 0.5;
        float light = smoothstep(0.3 * flicker, 0.0, dist);
        
        float3 lightCol = float3(1.0, 0.3, 0.1);  // Orange/red
        lightCol = mix(lightCol, float3(1.0, 0.8, 0.0), random(float2(i, t)));  // Yellow
        col += lightCol * light * 0.5;
    }
    
    // Aggressive bass reaction
    float bassFlash = u.bass;
    col += float3(0.2, 0.0, 0.0) * bassFlash;
    
    // Glitch effect on treble
    float glitch = step(0.95, random(floor(uv * 20.0) + floor(t * 10.0)));
    glitch *= u.treble;
    col = mix(col, float3(1.0), glitch);
    
    // Random scratchy lines
    float2 scratchP = p * 10.0;
    scratchP.x += random(floor(scratchP.y)) * 10.0;
    float scratch = step(0.98, random(floor(scratchP)));
    col += float3(scratch * 0.3);
    
    // Middle finger silhouette (simplified, censored bars)
    float2 handP = p - float2(0.0, -0.3);
    float hand = 0.0;
    
    // Fist shape
    float fist = length(handP);
    fist = smoothstep(0.2, 0.15, fist);
    
    // Finger bars (censored)
    float barSpacing = 0.04;
    float bars = step(mod(handP.x + 0.1, barSpacing), barSpacing * 0.6);
    bars *= step(abs(handP.y), 0.25);
    
    col = mix(col, float3(0.0), fist * bars * 0.8);
    
    // Distressed overlay
    float distress = noise(p * 30.0 + t);
    col *= 0.8 + distress * 0.4;
    
    // Color splatters
    float2 splatP = p * 3.0;
    float splat = noise(splatP + t * 0.5);
    splat = step(0.7, splat);
    float3 splatCol = random(float2(floor(splatP.x), floor(splatP.y)));
    col = mix(col, splatCol, splat * 0.3);
    
    // Vignette (rough)
    float vignette = 1.0 - length(uv - 0.5) * 0.8;
    vignette = pow(vignette, 2.0);
    col *= vignette;
    
    return float4(col, 1.0);
}
