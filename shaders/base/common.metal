#include "ShaderInterop.h"


#ifndef SHADER_BASE_METAL_H
#define SHADER_BASE_METAL_H

#include <metal_stdlib>
using namespace metal;

// Uniform buffer shared across all shaders
/* struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float4 date;
    int frame;
    float deltaTime;
    float2 padding;
}; */

// Standard vertex input for fullscreen quad
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

/* struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float2 screenPos;
}; */

// Utility functions
namespace ShaderUtils {
    // Vector operations
    inline float2 mod(float2 x, float2 y) { return x - y * floor(x / y); }
    inline float3 mod(float3 x, float3 y) { return x - y * floor(x / y); }
    inline float4 mod(float4 x, float4 y) { return x - y * floor(x / y); }
    
    inline float2 fract(float2 x) { return x - floor(x); }
    inline float3 fract(float3 x) { return x - floor(x); }
    inline float4 fract(float4 x) { return x - floor(x); }
    
    // Hash functions
    inline float hash(float n) { return fract(sin(n) * 43758.5453123); }
    inline float2 hash2(float2 p) {
        float3 p3 = fract(float3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.xx + p3.yz) * p3.zy);
    }
    inline float3 hash3(float2 p) {
        float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
        p3 += dot(p3, p3.yxz + 33.33);
        return fract((p3.xxy + p3.yzz) * p3.zyx);
    }
    
    // Noise functions
    inline float noise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        
        float n = i.x + i.y * 57.0;
        return mix(
            mix(hash(n + 0.0), hash(n + 1.0), f.x),
            mix(hash(n + 57.0), hash(n + 58.0), f.x),
            f.y
        );
    }
    
    // Simplex noise (3D)
    inline float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
    inline float4 mod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
    inline float4 permute(float4 x) { return mod289(((x * 34.0) + 1.0) * x); }
    inline float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
    
    inline float snoise(float3 v) {
        const float2 C = float2(1.0/6.0, 1.0/3.0);
        const float4 D = float4(0.0, 0.5, 1.0, 2.0);
        
        float3 i = floor(v + dot(v, C.yyy));
        float3 x0 = v - i + dot(i, C.xxx);
        
        float3 g = step(x0.yzx, x0.xyz);
        float3 l = 1.0 - g;
        float3 i1 = min(g.xyz, l.zxy);
        float3 i2 = max(g.xyz, l.zxy);
        
        float3 x1 = x0 - i1 + C.xxx;
        float3 x2 = x0 - i2 + C.yyy;
        float3 x3 = x0 - D.yyy;
        
        i = mod289(i);
        float4 p = permute(permute(permute(
            i.z + float4(0.0, i1.z, i2.z, 1.0))
            + i.y + float4(0.0, i1.y, i2.y, 1.0))
            + i.x + float4(0.0, i1.x, i2.x, 1.0));
        
        float n_ = 0.142857142857;
        float3 ns = n_ * D.wyz - D.xzx;
        
        float4 j = p - 49.0 * floor(p * ns.z * ns.z);
        
        float4 x_ = floor(j * ns.z);
        float4 y_ = floor(j - 7.0 * x_);
        
        float4 x = x_ * ns.x + ns.yyyy;
        float4 y = y_ * ns.x + ns.yyyy;
        float4 h = 1.0 - abs(x) - abs(y);
        
        float4 b0 = float4(x.xy, y.xy);
        float4 b1 = float4(x.zw, y.zw);
        
        float4 s0 = floor(b0) * 2.0 + 1.0;
        float4 s1 = floor(b1) * 2.0 + 1.0;
        float4 sh = -step(h, float4(0.0));
        
        float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
        float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
        
        float3 p0 = float3(a0.xy, h.x);
        float3 p1 = float3(a0.zw, h.y);
        float3 p2 = float3(a1.xy, h.z);
        float3 p3 = float3(a1.zw, h.w);
        
        float4 norm = taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
        p0 *= norm.x;
        p1 *= norm.y;
        p2 *= norm.z;
        p3 *= norm.w;
        
        float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
        m = m * m;
        return 42.0 * dot(m*m, float4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
    }
    
    // FBM (Fractal Brownian Motion)
    inline float fbm(float3 x, int octaves) {
        float v = 0.0;
        float a = 0.5;
        float3 shift = float3(100.0);
        
        for (int i = 0; i < octaves; ++i) {
            v += a * snoise(x);
            x = x * 2.0 + shift;
            a *= 0.5;
        }
        return v;
    }
    
    // Color utilities
    inline float3 hsv2rgb(float3 c) {
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }
    
    inline float3 rgb2hsv(float3 c) {
        float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
        float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
        float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
        
        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;
        return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    }
    
    // SDF primitives
    inline float sdSphere(float3 p, float r) {
        return length(p) - r;
    }
    
    inline float sdBox(float3 p, float3 b) {
        float3 d = abs(p) - b;
        return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
    }
    
    inline float sdTorus(float3 p, float2 t) {
        float2 q = float2(length(p.xz) - t.x, p.y);
        return length(q) - t.y;
    }
    
    // SDF operations
    inline float opUnion(float d1, float d2) { return min(d1, d2); }
    inline float opSubtraction(float d1, float d2) { return max(-d1, d2); }
    inline float opIntersection(float d1, float d2) { return max(d1, d2); }
    
    inline float opSmoothUnion(float d1, float d2, float k) {
        float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
        return mix(d2, d1, h) - k * h * (1.0 - h);
    }
    
    // Rotation matrices
    inline float3 rotateX(float3 p, float a) {
        float s = sin(a), c = cos(a);
        return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
    }
    
    inline float3 rotateY(float3 p, float a) {
        float s = sin(a), c = cos(a);
        return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
    }
    
    inline float3 rotateZ(float3 p, float a) {
        float s = sin(a), c = cos(a);
        return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
    }
}

// Vertex shader - standard fullscreen quad
vertex VertexOut vertex_main(
    VertexIn in [[stage_in]]
) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// Default fragment shader stub - will be overridden by specific shaders
fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]],
    texture2d<float> prevFrame [[texture(0)]],
    sampler frameSampler [[sampler(0)]]
) {
    // Injected default values for missing uniforms
    float u_padding = 1.0;

    float2 uv = in.texCoord;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    // Default effect - animated gradient
    float3 color = ShaderUtils::hsv2rgb(float3(
        uniforms.time * 0.1 + length(centered) * 0.5,
        0.8,
        0.5 + 0.5 * sin(uniforms.time + length(centered) * 3.0)
    ));
    
    return float4(color, 1.0);
}

#endif // SHADER_BASE_METAL_H
