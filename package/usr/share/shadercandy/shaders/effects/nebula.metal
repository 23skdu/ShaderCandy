// Nebula Cloud - Volumetric effect (Metal port)

#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Volume rendering of nebula
float nebula_density(float3 p, float t) {
    // Domain warp for organic movement
    float3 q = p;
    q.x += fbm(p + t, 3) * 0.5;
    q.y += fbm(p + t + 100.0, 3) * 0.5;
    q.z += fbm(p + t + 200.0, 3) * 0.5;
    
    // Multiple layers of FBM for cloud density
    float density = 0.0;
    float amp = 0.5;
    float3 offset = float3(t * 0.2, t * 0.1, t * 0.15);
    
    for (int i = 0; i < 5; i++) {
        density += amp * snoise(q * (1.0 + float(i) * 0.5) + offset);
        q = q * 2.0 + offset;
        amp *= 0.5;
    }
    
    // Create swirling arms
    float angle = atan2(p.z, p.x);
    float radius = length(p.xz);
    float spiral = sin(angle * 3.0 + radius * 2.0 - t);
    density += spiral * 0.2 * exp(-radius * 0.5);
    
    return max(density, 0.0);
}

// Star field
float nebula_stars(float3 rd, float t) {
    float s = 0.0;
    float3 p = rd * 100.0;
    
    for (int i = 0; i < 3; i++) {
        float3 grid = floor(p);
        float h = hash(grid.x + grid.y * 57.0 + grid.z * 113.0 + float(i) * 437.0);
        if (h > 0.98) {
            float size = hash(grid.x * 2.0) * 0.5 + 0.5;
            float twinkle = sin(t * 20.0 + h * 10.0) * 0.5 + 0.5;
            s += twinkle * size * smoothstep(0.02, 0.0, length(fract(p) - 0.5));
        }
        p *= 1.5;
    }
    
    return s;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 centered = in.texCoord * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    float t = uniforms.time * uniforms.speed * 0.5;
    
    // Camera setup
    float camRadius = 4.0 + sin(t * 0.2) * 0.5;
    float3 ro = float3(
        cos(t * 0.1) * camRadius,
        sin(t * 0.05) * 0.5,
        sin(t * 0.1) * camRadius
    );
    float3 ta = float3(0.0, 0.0, 0.0);
    
    // Camera matrix
    float3 ww = normalize(ta - ro);
    float3 uu = normalize(cross(ww, float3(0, 1, 0)));
    float3 vv = normalize(cross(uu, ww));
    
    // Ray direction
    float3 rd = normalize(centered.x * uu + centered.y * vv + 1.5 * ww);
    
    // Background stars
    float3 col = float3(0.0);
    col += float3(0.8, 0.9, 1.0) * nebula_stars(rd, t) * 0.5;
    
    // Ray march volume
    float4 vol = float4(0.0);
    float dist = 0.5;
    
    float3 col1 = float3(0.1, 0.0, 0.3);  // Deep purple
    float3 col2 = float3(0.0, 0.2, 0.5);  // Blue
    float3 col3 = float3(0.0, 0.6, 0.7);  // Cyan
    float3 col4 = float3(0.8, 0.3, 0.1);  // Orange
    float3 col5 = float3(1.0, 0.9, 0.7);  // White/yellow core
    
    for (int i = 0; i < 64; i++) {
        if (vol.a > 0.99) break;
        
        float3 p = ro + dist * rd;
        float d = nebula_density(p, t);
        
        if (d > 0.01) {
            float hue = d * 0.5 + length(p) * 0.1;
            float3 sampleCol = mix(col1, col2, smoothstep(0.0, 0.3, hue));
            sampleCol = mix(sampleCol, col3, smoothstep(0.3, 0.5, hue));
            sampleCol = mix(sampleCol, col4, smoothstep(0.5, 0.7, hue));
            sampleCol = mix(sampleCol, col5, smoothstep(0.7, 1.0, d));
            
            d *= 0.1;
            vol.rgb += (1.0 - vol.a) * sampleCol * d;
            vol.a += (1.0 - vol.a) * d;
        }
        
        dist += 0.02 + dist * 0.01;
    }
    
    col = mix(col, vol.rgb, vol.a);
    
    // Add bright core glow
    float core = max(0.0, snoise(rd * 3.0 + t * 0.5));
    col += float3(1.0, 0.9, 0.7) * core * core * 0.3;
    
    // Post-processing
    col = col / (1.0 + col);
    col = pow(col, float3(0.4545));
    col *= 1.0 - length(centered) * 0.2;
    
    return float4(col * uniforms.intensity, uniforms.alpha);
}
