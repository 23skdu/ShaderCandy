// Electronic - EDM/Festival style with laser beams and pulsing energy

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

fragment float4 electronic_fragment(VertexOut in [[stage_in]],
                                   constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float t = u.time * 0.6;
    
    // Deep dark background
    float3 col = float3(0.02, 0.02, 0.05);
    
    // Beat pulse from bass
    float bassPulse = u.bass;
    float midPulse = u.mid;
    float treblePulse = u.treble;
    
    // Laser beams from center
    float numLasers = 8.0;
    float angle = atan2(p.y, p.x);
    float laserAngle = mod(angle + t * 0.5, 6.28318 / numLasers);
    laserAngle = abs(laserAngle - 3.14159 / numLasers);
    
    float laser = smoothstep(0.15, 0.0, laserAngle);
    laser *= smoothstep(1.5, 0.2, length(p));
    
    // Laser colors cycling
    float colorCycle = fract(t * 0.3);
    float3 laserCol1 = float3(1.0, 0.0, 0.5);  // Magenta
    float3 laserCol2 = float3(0.0, 1.0, 1.0);   // Cyan
    float3 laserCol3 = float3(1.0, 1.0, 0.0);    // Yellow
    float3 laserCol;
    
    float laserIdx = floor(mod(t * 0.5 + laserAngle * 2.0, 3.0));
    laserCol = laserCol1;
    laserCol = mix(laserCol, laserCol2, step(1.0, laserIdx));
    laserCol = mix(laserCol, laserCol3, step(2.0, laserIdx));
    
    col = mix(col, laserCol, laser * (0.5 + bassPulse * 0.5));
    
    // Energy rings from center
    float ringDist = length(p);
    float rings = sin(ringDist * 20.0 - t * 4.0);
    rings = smoothstep(0.0, 0.5, rings);
    rings *= smoothstep(1.2, 0.0, ringDist);
    
    float3 ringCol = mix(float3(0.0, 0.5, 1.0), float3(1.0, 0.0, 0.5), sin(t) * 0.5 + 0.5);
    col = mix(col, ringCol, rings * 0.4 * (1.0 + bassPulse));
    
    // Beat drop - explosion from center
    float explosion = smoothstep(0.5 + bassPulse * 0.3, 0.0, ringDist);
    explosion *= bassPulse;
    float3 explosionCol = float3(1.0, 0.8, 0.0);  // Bright yellow/white
    col = mix(col, explosionCol, explosion);
    
    // Treble - starburst/high frequency sparkles
    float2 sparkleUV = p * 8.0;
    float sparkle = noise(sparkleUV + t * 3.0);
    sparkle = pow(sparkle, 8.0) * treblePulse;
    
    // Grid floor with perspective
    float2 floorP = p;
    floorP.y = 1.0 - floorP.y;
    floorP.y = 1.0 / (floorP.y + 0.5);
    floorP.x *= floorP.y * 2.0;
    
    float floorGrid = abs(fract(floorP.x * 2.0 - t * 2.0) - 0.5);
    floorGrid += abs(fract(floorP.y * 2.0) - 0.5);
    floorGrid = smoothstep(0.1, 0.0, floorGrid);
    
    float floorFade = smoothstep(0.0, 0.3, uv.y);
    float3 floorCol = mix(float3(0.0, 0.8, 1.0), float3(0.5, 0.0, 0.5), uv.y);
    col = mix(col, floorCol * 0.3, floorGrid * floorFade * 0.5);
    
    // Side beams/structures
    float sideBeam = smoothstep(0.8, 0.6, abs(p.x));
    sideBeam *= smoothstep(-0.5, 0.5, p.y);
    float3 beamCol = mix(float3(0.0, 1.0, 0.5), float3(1.0, 0.0, 0.5), sin(p.y * 5.0 + t) * 0.5 + 0.5);
    col = mix(col, beamCol * 0.5, sideBeam * 0.3);
    
    // Mid frequencies - waveform visualization
    float waveY = sin(p.x * 10.0 + t * 3.0) * 0.1 * midPulse;
    float wave = smoothstep(0.02, 0.0, abs(p.y - waveY - 0.3));
    col = mix(col, float3(1.0, 0.5, 0.0), wave * 0.5);
    
    // Bass kick flash
    float kick = bassPulse * smoothstep(0.8, 0.3, uv.y);
    col += float3(0.2, 0.0, 0.3) * kick;
    
    // Vignette for focus
    float vignette = 1.0 - length(uv - 0.5) * 0.6;
    col *= vignette;
    
    // Glow/bloom approximation
    col += col * 0.2;
    
    // Clamp for intensity
    col *= u.intensity;
    
    return float4(col, 1.0);
}
