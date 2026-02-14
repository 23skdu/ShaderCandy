#ifndef SHADER_UTILS_METAL
#define SHADER_UTILS_METAL

#include <metal_stdlib>
using namespace metal;

// Utility functions for Metal Shaders
namespace ShaderUtils {
    // Scalar and Vector operations
    inline float mod(float x, float y) { return fmod(x, y); }
    inline float2 mod(float2 x, float2 y) { return fmod(x, y); }
    inline float3 mod(float3 x, float3 y) { return fmod(x, y); }
    inline float4 mod(float4 x, float4 y) { return fmod(x, y); }
    
    // Using Metal built-in fract
    
    // Hash functions
    // Hash functions
    inline float hash(float n) { return fract(sin(n) * 43758.5453123f); }
    inline float hash(float2 p) { return fract(sin(dot(p, float2(12.9898f, 78.233f))) * 43758.5453f); }
    inline float2 hash2(float2 p) {
        float3 p3 = fract(float3(p.xyx) * 0.1031f);
        p3 += dot(p3, p3.yzx + 33.33f);
        return fract((p3.xx + p3.yz) * p3.zy);
    }
    inline float3 hash3(float2 p) {
        float3 p3 = fract(float3(p.xyx) * float3(0.1031f, 0.1030f, 0.0973f));
        p3 += dot(p3, p3.yxz + 33.33f);
        return fract((p3.xxy + p3.yzz) * p3.zyx);
    }
    
    // Noise functions
    inline float noise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0f - 2.0f * f);
        
        float n = i.x + i.y * 57.0f;
        return mix(
            mix(hash(n + 0.0f), hash(n + 1.0f), f.x),
            mix(hash(n + 57.0f), hash(n + 58.0f), f.x),
            f.y
        );
    }
    
    // Simplex noise (3D)
    inline float2 mod289(float2 x) { return x - floor(x * (1.0f / 289.0f)) * 289.0f; }
    inline float3 mod289(float3 x) { return x - floor(x * (1.0f / 289.0f)) * 289.0f; }
    inline float4 mod289(float4 x) { return x - floor(x * (1.0f / 289.0f)) * 289.0f; }
    
    inline float3 permute(float3 x) { return mod289(((x * 34.0f) + 1.0f) * x); }
    inline float4 permute(float4 x) { return mod289(((x * 34.0f) + 1.0f) * x); }
    
    inline float4 taylorInvSqrt(float4 r) { return 1.79284291400159f - 0.85373472095314f * r; }
    
    inline float snoise(float3 v) {
        const float2 C = float2(1.0f/6.0f, 1.0f/3.0f);
        const float4 D = float4(0.0f, 0.5f, 1.0f, 2.0f);
        
        float3 i = floor(v + dot(v, C.yyy));
        float3 x0 = v - i + dot(i, C.xxx);
        
        float3 g = step(x0.yzx, x0.xyz);
        float3 l = 1.0f - g;
        float3 i1 = min(g.xyz, l.zxy);
        float3 i2 = max(g.xyz, l.zxy);
        
        float3 x1 = x0 - i1 + C.xxx;
        float3 x2 = x0 - i2 + C.yyy;
        float3 x3 = x0 - D.yyy;
        
        i = mod289(i);
        float4 p = permute(permute(permute(
            i.z + float4(0.0f, i1.z, i2.z, 1.0f))
            + i.y + float4(0.0f, i1.y, i2.y, 1.0f))
            + i.x + float4(0.0f, i1.x, i2.x, 1.0f));
        
        float n_ = 0.142857142857f;
        float3 ns = n_ * D.wyz - D.xzx;
        
        float4 j = p - 49.0f * floor(p * ns.z * ns.z);
        
        float4 x_ = floor(j * ns.z);
        float4 y_ = floor(j - 7.0f * x_);
        
        float4 x = x_ * ns.x + ns.yyyy;
        float4 y = y_ * ns.x + ns.yyyy;
        float4 h = 1.0f - abs(x) - abs(y);
        
        float4 b0 = float4(x.xy, y.xy);
        float4 b1 = float4(x.zw, y.zw);
        
        float4 s0 = floor(b0) * 2.0f + 1.0f;
        float4 s1 = floor(b1) * 2.0f + 1.0f;
        float4 sh = -step(h, float4(0.0f));
        
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
        
        float4 m = max(0.6f - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0f);
        m = m * m;
        return 42.0f * dot(m * m, float4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
    }
    
    // FBM (Fractal Brownian Motion)
    inline float fbm(float3 x, int octaves) {
        float v = 0.0f;
        float a = 0.5f;
        float3 shift = float3(100.0f);
        
        for (int i = 0; i < octaves; ++i) {
            v += a * snoise(x);
            x = x * 2.0f + shift;
            a *= 0.5f;
        }
        return v;
    }
    
    // Color utilities
    inline float3 hsv2rgb(float3 c) {
        float4 K = float4(1.0f, 2.0f / 3.0f, 1.0f / 3.0f, 3.0f);
        float3 p = abs(fract(c.xxx + K.xyz) * 6.0f - K.www);
        return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0f, 1.0f), c.y);
    }
    
    // SDF primitives
    inline float sdSphere(float3 p, float r) {
        return length(p) - r;
    }
    
    inline float sdBox(float3 p, float3 b) {
        float3 d = abs(p) - b;
        return min(max(d.x, max(d.y, d.z)), 0.0f) + length(max(d, 0.0f));
    }
    
    inline float3x3 lookAt(float3 ro, float3 ta) {
        float3 f = normalize(ta - ro);
        float3 r = normalize(cross(float3(0, 1, 0), f));
        float3 u = cross(f, r);
        return float3x3(r, u, f);
    }
    
    inline float stepped_noise(float3 p) {
        float3 i = floor(p);
        return hash(dot(i, float3(1, 57, 113)));
    }
    
    inline float custom_noise(float2 p) { return noise(p); }
    inline float custom_random(float2 p) { return hash(p); }
    
    // Rotation matrices (Updated for speed using standard functions)
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

    // --- Compatibility Helpers ---
    
    // 2D Rotation Matrix
    inline float2x2 rot(float a) {
        float s = sin(a), c = cos(a);
        return float2x2(c, -s, s, c);
    }
    
    // 3D Rotation Matrices
    inline float3x3 rotX(float a) {
        float s = sin(a), c = cos(a);
        return float3x3(1, 0, 0, 0, c, -s, 0, s, c);
    }
    
    inline float3x3 rotY(float a) {
        float s = sin(a), c = cos(a);
        return float3x3(c, 0, s, 0, 1, 0, -s, 0, c);
    }
    
    inline float3x3 rotZ(float a) {
        float s = sin(a), c = cos(a);
        return float3x3(c, -s, 0, s, c, 0, 0, 0, 1);
    }

    // 2D Simplex Noise (Adapted)
    inline float snoise(float2 v) {
        const float4 C = float4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                              0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                             -0.577350269189626,  // -1.0 + 2.0 * C.x
                              0.024390243902439); // 1.0 / 41.0
        float2 i  = floor(v + dot(v, C.yy));
        float2 x0 = v - i + dot(i, C.xx);
        float2 i1;
        i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
        float4 x12 = x0.xyxy + C.xxzz;
        x12.xy -= i1;
        i = mod289(i);
        float3 p = permute( permute( i.y + float3(0.0, i1.y, 1.0 ))
             + i.x + float3(0.0, i1.x, 1.0 ));
        float3 m = max(0.5 - float3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
        m = m*m ;
        m = m*m ;
        float3 x = 2.0 * fract(p * C.www) - 1.0;
        float3 h = abs(x) - 0.5;
        float3 ox = floor(x + 0.5);
        float3 a0 = x - ox;
        m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
        float3 g;
        g.x  = a0.x  * x0.x  + h.x  * x0.y;
        g.yz = a0.yz * x12.xz + h.yz * x12.yw;
        return 130.0 * dot(m, g);
    }
}

// Expose Utils globally
using namespace ShaderUtils;

#endif // SHADER_UTILS_METAL
