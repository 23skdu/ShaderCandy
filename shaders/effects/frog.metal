// Frog 3D - Pond Life with Sun Orbit
#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

using namespace ShaderUtils;

float sdEllipsoid(float3 p, float3 r) {
    float k0 = length(p/r);
    float k1 = length(p/(r*r));
    return k0*(k0-1.0)/k1;
}

float map(float3 p, float time) {
    // Water surface
    float water = p.y + 0.5 + 0.05 * sin(p.x * 4.0 + time) * cos(p.z * 4.0 + time);
    
    // Lily pad
    float2 lp_pos = float2(0,0);
    float pad = length(p.xz - lp_pos) - 1.2;
    pad = max(pad, abs(p.y + 0.4) - 0.05);
    // Notch in lily pad
    float notch = length(p.xz - lp_pos - float2(1.0, 0.0)) - 0.5;
    pad = max(pad, -notch);
    
    // Frog body (simplified)
    float3 fp = p - float3(0.0, -0.1, 0.0);
    float body = sdEllipsoid(fp, float3(0.4, 0.3, 0.5));
    
    // Eyes
    float eyeL = sdSphere(fp - float3(-0.2, 0.2, 0.3), 0.15);
    float eyeR = sdSphere(fp - float3(0.2, 0.2, 0.3), 0.15);
    
    float d = min(water, pad);
    d = min(d, body);
    d = min(d, min(eyeL, eyeR));
    
    return d;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed;
    
    // Sun orbit in sky
    float sunOrbitRadius = 8.0;
    float sunAngle = t * 0.1; // Slow orbit
    float3 sunPos = float3(
        cos(sunAngle) * sunOrbitRadius,
        sin(sunAngle) * sunOrbitRadius * 0.5 + 3.0, // Arc across sky
        -5.0
    );
    
    // X-axis rotation for camera
    float xRotation = sin(t * 0.05) * 0.3; // Gentle rocking
    float3x3 rotX = float3x3(
        1, 0, 0,
        0, cos(xRotation), -sin(xRotation),
        0, sin(xRotation), cos(xRotation)
    );
    
    float3 ro = float3(2.5 * sin(t*0.2), 1.5, -3.5);
    float3 rd = normalize(float3(uv, 1.2));
    rd = rotX * lookAt(ro, float3(0,0,0)) * rd;
    
    float dTotal = 0.0;
    float d;
    float3 accumulatedColor = float3(0.0);
    
    for(int i=0; i<80; i++) {
        float3 p = ro + rd * dTotal;
        d = map(p, t);
        
        if(d < 0.001 || dTotal > 20.0) break;
        dTotal += d;
    }
    
    // Sky gradient based on sun position
    float sunHeight = sunPos.y / sunOrbitRadius;
    float3 skyColorTop = mix(
        float3(0.0, 0.1, 0.3),    // Deep blue
        float3(0.9, 0.6, 0.3),    // Sunset orange
        smoothstep(-0.5, 0.5, sunHeight)
    );
    float3 skyColorBottom = mix(
        float3(0.3, 0.5, 0.7),    // Light blue
        float3(0.9, 0.4, 0.2),    // Sunset red
        smoothstep(-0.5, 0.5, sunHeight)
    );
    
    float3 color = mix(skyColorBottom, skyColorTop, in.texCoord.y);
    
    // Sun rendering
    float2 sunUV = in.texCoord - float2(0.5 + sunPos.x * 0.05, 0.5 + (sunPos.y - 3.0) * 0.05);
    float sunDist = length(sunUV);
    float sun = smoothstep(0.08, 0.06, sunDist);
    float3 sunColor = float3(1.0, 0.9, 0.6);
    
    // Sun glow
    float sunGlow = exp(-sunDist * 3.0) * 0.3;
    
    // Add sun to background
    if(dTotal > 15.0 || dTotal == 0.0) {
        color = mix(color, sunColor, sun);
        color += sunColor * sunGlow;
    }
    
    if(dTotal < 20.0 && dTotal > 0.0) {
        float3 p = ro + rd * dTotal;
        float3 n = normalize(float3(
            map(p + float3(0.01,0,0), t) - map(p - float3(0.01,0,0), t),
            map(p + float3(0,0.01,0), t) - map(p - float3(0,0.01,0), t),
            map(p + float3(0,0,0.01), t) - map(p - float3(0,0,0.01), t)
        ));
        
        // Lighting from sun
        float3 toSun = normalize(sunPos - p);
        float diff = max(dot(n, toSun), 0.0);
        float spec = pow(max(dot(reflect(-toSun, n), -rd), 0.0), 32.0);
        
        // Ambient light
        float ambient = 0.3 + 0.4 * max(sunHeight, 0.0);
        
        // Coloring
        if(p.y < -0.42) {
            // Water
            color = float3(0.1, 0.4, 0.6) * (diff * 0.7 + ambient);
            // Sun reflection
            float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
            color += float3(0.8, 0.9, 1.0) * spec * 0.5;
            color += sunColor * fresnel * 0.3 * sun;
        } else if(length(p.xz) < 1.3 && p.y < -0.3) {
            // Lily pad
            color = float3(0.1, 0.5, 0.1) * (diff + ambient);
            // Vein pattern
            float vein = sin(length(p.xz) * 10.0 + atan2(p.z, p.x) * 3.0);
            color *= 0.9 + 0.1 * vein;
        } else {
            // Frog
            float3 frogCol = float3(0.4, 0.8, 0.2);
            // Eyes
            if(p.y > 0.0) {
                float pupil = smoothstep(0.05, 0.04, length(p.xy - float2(p.x > 0 ? 0.2 : -0.2, 0.2)));
                frogCol = mix(frogCol, float3(0.0), pupil);
            }
            color = frogCol * (diff + ambient);
            color += float3(1.0) * spec * 0.3;
        }
        
        // Fog based on sun position
        float fogAmount = 1.0 - exp(-dTotal * 0.15);
        float3 fogColor = mix(
            float3(0.4, 0.6, 0.7),
            float3(0.9, 0.6, 0.4),
            smoothstep(-0.5, 0.5, sunHeight)
        );
        color = mix(color, fogColor, fogAmount);
    } else {
        // Full sky with sun
        color = mix(color, sunColor, sun);
        color += sunColor * sunGlow;
    }
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}