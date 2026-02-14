// Mandelbulb 3D Fractal
// Raymarching implementation with Pulsating Power and Colors

#include "ShaderInterop.h"
#include "utils.metal"

using namespace metal;

// Mandelbulb distance estimator
float map(float3 p, thread float& trap, float time) {
    float3 z = p;
    float dr = 1.0;
    float r = 0.0;
    
    // Pulsate Power between 2 and 10
    float Power = 6.0 + 4.0 * sin(time * 0.5);
    
    for (int i = 0; i < 8; i++) {
        r = length(z);
        if (r > 2.0) break;
        
        // Convert to polar coordinates
        float theta = acos(z.z / r);
        float phi = atan2(z.y, z.x);
        dr = pow(r, Power - 1.0) * Power * dr + 1.0;
        
        // Scale and rotate z
        float zr = pow(r, Power);
        theta = theta * Power;
        phi = phi * Power;
        
        // Convert back to cartesian coordinates
        z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
        z += p;
        
        trap = min(trap, length(z));
    }
    return 0.5 * log(r) * r / dr;
}

float3 getNormal(float3 p, float time) {
    float dummy = 0.0;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + e.xyy, dummy, time) - map(p - e.xyy, dummy, time),
        map(p + e.yxy, dummy, time) - map(p - e.yxy, dummy, time),
        map(p + e.yyx, dummy, time) - map(p - e.yyx, dummy, time)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed * 0.2;
    
    // Camera setup
    float3 ro = float3(2.5 * sin(t), 1.5 * cos(t * 0.5), 2.5 * cos(t));
    float3 lookat = float3(0.0);
    float3 fwd = normalize(lookat - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Raymarching
    float d = 0.0;
    float t_dist = 0.0;
    float trap = 1e10;
    float3 p;
    
    for (int i = 0; i < 128; i++) {
        p = ro + rd * t_dist;
        d = map(p, trap, uniforms.time);
        if (d < 0.001 || t_dist > 10.0) break;
        t_dist += d;
    }
    
    float3 color = float3(0.0);
    if (t_dist < 10.0) {
        float3 norm = getNormal(p, uniforms.time);
        float3 lightPos = float3(5.0, 5.0, 5.0);
        float3 lightDir = normalize(lightPos - p);
        float diff = max(0.0, dot(norm, lightDir));
        
        // Coloring based on orbit trap and time
        float3 baseCol = hsv2rgb(float3(fract(trap * 0.2 + uniforms.time * 0.1), 0.8, 1.0));
        color = baseCol * (diff + 0.1);
        
        // Fog
        color = mix(color, float3(0.0), 1.0 - exp(-0.1 * t_dist));
    }
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
