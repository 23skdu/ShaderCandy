#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

//
//  astra_fractal.metal
//  ShaderCandy
//
//  3D Mandelbox fractal tunnel with psychedelic color shifts and enhanced zoom
//

using namespace ShaderUtils;

// Mandelbox Fold
void boxFold(thread float3& z, thread float& dz) {
    z = clamp(z, -1.0, 1.0) * 2.0 - z;
}

void sphereFold(thread float3& z, thread float& dz) {
    float r2 = dot(z, z);
    if (r2 < 0.5) {
        float temp = 2.0;
        z *= temp;
        dz *= temp;
    } else if (r2 < 1.0) {
        float temp = 1.0 / r2;
        z *= temp;
        dz *= temp;
    }
}

float mboxSDF(float3 p, float t, float zoom) {
    float3 z = p;
    float dr = 1.0;
    float scale = 2.6 + 0.3 * sin(t * 0.5) + zoom * 0.5;
    
    for (int i = 0; i < 12; i++) {
        boxFold(z, dr);
        sphereFold(z, dr);
        z = scale * z + p;
        dr = dr * abs(scale) + 1.0;
    }
    return length(z) / abs(dr);
}

// Julia set variation for extra detail
float juliaSDF(float3 p, float t) {
    float3 z = p;
    float dr = 1.0;
    float3 c = float3(sin(t * 0.3) * 0.3, cos(t * 0.2) * 0.3, sin(t * 0.4) * 0.2);
    
    for (int i = 0; i < 8; i++) {
        dr = 2.0 * length(z) * dr + 1.0;
        z = float3(
            z.x * z.x - z.y * z.y - z.z * z.z,
            2.0 * z.x * z.y,
            2.0 * z.x * z.z
        ) + c;
        if (dot(z, z) > 4.0) break;
    }
    return 0.5 * log(length(z)) * length(z) / dr;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Dynamic zoom effect
    float zoomPhase = sin(t * 0.3) * 0.5 + 0.5;
    float zoom = 1.0 + zoomPhase * 3.0; // Zoom from 1x to 4x
    float tunnelDepth = t * 0.5;
    
    // Camera with zoom movement
    float3 ro = float3(
        sin(t * 0.2) * 0.5,
        cos(t * 0.15) * 0.3,
        -3.0 - zoomPhase * 5.0 + sin(tunnelDepth) * 0.5
    );
    
    // Target moves through the fractal
    float3 ta = float3(
        sin(t * 0.25) * 2.0,
        cos(t * 0.2) * 2.0,
        tunnelDepth
    );
    
    float3 fwd = normalize(ta - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    
    // Add subtle camera rotation
    float rotAngle = t * 0.1;
    float2x2 rot = float2x2(cos(rotAngle), -sin(rotAngle), sin(rotAngle), cos(rotAngle));
    uv = rot * uv;
    
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Raymarch with increased iterations for detail
    float d = 0.0, t_dist = 0.0;
    float3 p = ro;
    float glow = 0.0;
    
    for (int i = 0; i < 128; i++) {
        p = ro + rd * t_dist;
        
        // Combine Mandelbox and Julia for complex patterns
        float d1 = mboxSDF(p, t, zoom);
        float d2 = juliaSDF(p * 0.5 + float3(sin(t), cos(t), 0), t);
        
        d = min(d1, d2);
        
        // Accumulate glow
        glow += 0.01 / (1.0 + d * 5.0);
        
        if (d < 0.0005 || t_dist > 15.0) break;
        t_dist += d * 0.5;
    }
    
    float3 color = float3(0.0);
    
    if (t_dist < 15.0) {
        // Calculate normal
        float2 e = float2(0.001, 0.0);
        float3 normal = normalize(float3(
            mboxSDF(p + e.xyy, t, zoom) - mboxSDF(p - e.xyy, t, zoom),
            mboxSDF(p + e.yxy, t, zoom) - mboxSDF(p - e.yxy, t, zoom),
            mboxSDF(p + e.yyx, t, zoom) - mboxSDF(p - e.yyx, t, zoom)
        ));
        
        float diff = max(0.0, dot(normal, normalize(float3(1, 2, -3))));
        
        // Vibrant rainbow colors based on position and time
        float hue1 = fract(t_dist * 0.15 + t * 0.15 + length(p) * 0.1);
        float hue2 = fract(t * 0.2 + p.y * 0.2 + sin(p.x * 2.0) * 0.1);
        
        float3 col1 = hsv2rgb(float3(hue1, 0.9, 1.0));
        float3 col2 = hsv2rgb(float3(hue2, 0.8, 0.9));
        
        // Blend colors based on depth
        color = mix(col1, col2, sin(t_dist * 0.5) * 0.5 + 0.5) * diff;
        
        // Specular highlight
        float3 lightDir = normalize(float3(1, 2, -3));
        float3 reflectDir = reflect(-lightDir, normal);
        float spec = pow(max(dot(rd, reflectDir), 0.0), 32.0);
        color += hsv2rgb(float3(fract(t * 0.3), 0.6, 1.0)) * spec * 0.5;
        
        // Add depth-based color shift
        color += exp(-t_dist * 0.3) * hsv2rgb(float3(fract(t * 0.5), 0.7, 1.0)) * 0.3;
        
        // Distance fog with vibrant colors
        float fogAmount = 1.0 - exp(-t_dist * 0.2);
        float3 fogColor = hsv2rgb(float3(fract(t * 0.1), 0.5, 0.3));
        color = mix(color, fogColor, fogAmount * 0.4);
    } else {
        // Background with starfield effect
        color = float3(0.02, 0.0, 0.08);
        
        // Star particles
        float2 starUV = uv * 20.0;
        float2 starId = floor(starUV);
        float2 starFract = fract(starUV);
        float star = step(0.97, hash(starId + floor(t * 0.1)));
        color += hsv2rgb(float3(hash(starId), 0.8, 1.0)) * star * 0.5;
        
        // Vignette
        color *= (1.0 - length(uv) * 0.3);
    }
    
    // Add accumulated glow
    float3 glowColor = hsv2rgb(float3(fract(t * 0.2 + t_dist * 0.1), 0.9, 1.0));
    color += glow * glowColor * 0.15;
    
    // Chromatic aberration for psychedelic effect
    float aberration = 0.01 * zoomPhase;
    // (Applied during final output for visual effect)
    
    // Intensity adjustment with saturation boost
    color = pow(color, float3(0.9)); // Slight gamma correction
    color *= uniforms.intensity * 1.2;
    
    return float4(color, uniforms.alpha);
}
