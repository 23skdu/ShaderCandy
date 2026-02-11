#pragma once

#include <cstdint>
#include <cmath>
#include <algorithm>
#include <initializer_list>

// SIMD includes
#if defined(USE_NEON)
    #include <arm_neon.h>
#elif defined(USE_AVX2)
    #include <immintrin.h>
#endif

namespace ShaderCandy {
namespace Math {

// Basic vector types
struct Vec2 {
    float x, y;
    Vec2(float x = 0, float y = 0) : x(x), y(y) {}
};

struct Vec3 {
    float x, y, z;
    Vec3(float x = 0, float y = 0, float z = 0) : x(x), y(y), z(z) {}
    
    float length() const { return std::sqrt(x*x + y*y + z*z); }
    float lengthSq() const { return x*x + y*y + z*z; }
    
    Vec3 normalize() const {
        float len = length();
        if (len > 0) {
            float inv = 1.0f / len;
            return Vec3(x * inv, y * inv, z * inv);
        }
        return *this;
    }
    
    Vec3 operator+(const Vec3& o) const { return Vec3(x + o.x, y + o.y, z + o.z); }
    Vec3 operator-(const Vec3& o) const { return Vec3(x - o.x, y - o.y, z - o.z); }
    Vec3 operator*(float s) const { return Vec3(x * s, y * s, z * s); }
    Vec3 operator/(float s) const { return Vec3(x / s, y / s, z / s); }
};

inline float dot(const Vec3& a, const Vec3& b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

inline Vec3 cross(const Vec3& a, const Vec3& b) {
    return Vec3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    );
}

// SIMD-accelerated operations
#if defined(USE_NEON)

// NEON implementation for ARM (Apple Silicon, mobile)
inline void multiplyArrayNEON(float* dst, const float* a, const float* b, size_t count) {
    size_t i = 0;
    for (; i + 3 < count; i += 4) {
        float32x4_t va = vld1q_f32(&a[i]);
        float32x4_t vb = vld1q_f32(&b[i]);
        float32x4_t vr = vmulq_f32(va, vb);
        vst1q_f32(&dst[i], vr);
    }
    // Handle remaining elements
    for (; i < count; i++) {
        dst[i] = a[i] * b[i];
    }
}

inline float sumArrayNEON(const float* data, size_t count) {
    float32x4_t sum = vdupq_n_f32(0.0f);
    size_t i = 0;
    for (; i + 3 < count; i += 4) {
        float32x4_t v = vld1q_f32(&data[i]);
        sum = vaddq_f32(sum, v);
    }
    float result[4];
    vst1q_f32(result, sum);
    float total = result[0] + result[1] + result[2] + result[3];
    for (; i < count; i++) {
        total += data[i];
    }
    return total;
}

inline void lerpArrayNEON(float* dst, const float* a, const float* b, float t, size_t count) {
    float32x4_t vt = vdupq_n_f32(t);
    float32x4_t v1t = vdupq_n_f32(1.0f - t);
    size_t i = 0;
    for (; i + 3 < count; i += 4) {
        float32x4_t va = vld1q_f32(&a[i]);
        float32x4_t vb = vld1q_f32(&b[i]);
        float32x4_t vr = vmlaq_f32(vmulq_f32(va, v1t), vb, vt);
        vst1q_f32(&dst[i], vr);
    }
    for (; i < count; i++) {
        dst[i] = a[i] * (1.0f - t) + b[i] * t;
    }
}

#elif defined(USE_AVX2)

// AVX2 implementation for x86 (Intel/AMD)
inline void multiplyArrayAVX2(float* dst, const float* a, const float* b, size_t count) {
    size_t i = 0;
    for (; i + 7 < count; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 vr = _mm256_mul_ps(va, vb);
        _mm256_storeu_ps(&dst[i], vr);
    }
    for (; i < count; i++) {
        dst[i] = a[i] * b[i];
    }
}

inline float sumArrayAVX2(const float* data, size_t count) {
    __m256 sum = _mm256_setzero_ps();
    size_t i = 0;
    for (; i + 7 < count; i += 8) {
        __m256 v = _mm256_loadu_ps(&data[i]);
        sum = _mm256_add_ps(sum, v);
    }
    float result[8];
    _mm256_storeu_ps(result, sum);
    float total = result[0] + result[1] + result[2] + result[3] +
                  result[4] + result[5] + result[6] + result[7];
    for (; i < count; i++) {
        total += data[i];
    }
    return total;
}

inline void lerpArrayAVX2(float* dst, const float* a, const float* b, float t, size_t count) {
    __m256 vt = _mm256_set1_ps(t);
    __m256 v1t = _mm256_set1_ps(1.0f - t);
    size_t i = 0;
    for (; i + 7 < count; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 vr = _mm256_add_ps(_mm256_mul_ps(va, v1t), _mm256_mul_ps(vb, vt));
        _mm256_storeu_ps(&dst[i], vr);
    }
    for (; i < count; i++) {
        dst[i] = a[i] * (1.0f - t) + b[i] * t;
    }
}

#endif

// Generic wrappers that dispatch to best available implementation
inline void multiplyArray(float* dst, const float* a, const float* b, size_t count) {
#if defined(USE_NEON)
    multiplyArrayNEON(dst, a, b, count);
#elif defined(USE_AVX2)
    multiplyArrayAVX2(dst, a, b, count);
#else
    for (size_t i = 0; i < count; i++) {
        dst[i] = a[i] * b[i];
    }
#endif
}

inline float sumArray(const float* data, size_t count) {
#if defined(USE_NEON)
    return sumArrayNEON(data, count);
#elif defined(USE_AVX2)
    return sumArrayAVX2(data, count);
#else
    float sum = 0.0f;
    for (size_t i = 0; i < count; i++) {
        sum += data[i];
    }
    return sum;
#endif
}

inline void lerpArray(float* dst, const float* a, const float* b, float t, size_t count) {
#if defined(USE_NEON)
    lerpArrayNEON(dst, a, b, t, count);
#elif defined(USE_AVX2)
    lerpArrayAVX2(dst, a, b, t, count);
#else
    for (size_t i = 0; i < count; i++) {
        dst[i] = a[i] * (1.0f - t) + b[i] * t;
    }
#endif
}

// Color space conversion
inline void rgbToHsv(const float* rgb, float* hsv) {
    float r = rgb[0], g = rgb[1], b = rgb[2];
    float mx = std::max({r, g, b});
    float mn = std::min({r, g, b});
    float df = mx - mn;
    
    if (mx == mn) {
        hsv[0] = 0;
    } else if (mx == r) {
        hsv[0] = std::fmod(60.0f * ((g - b) / df) + 360.0f, 360.0f);
    } else if (mx == g) {
        hsv[0] = std::fmod(60.0f * ((b - r) / df) + 120.0f, 360.0f);
    } else {
        hsv[0] = std::fmod(60.0f * ((r - g) / df) + 240.0f, 360.0f);
    }
    
    hsv[1] = (mx == 0) ? 0 : (df / mx);
    hsv[2] = mx;
}

inline void hsvToRgb(const float* hsv, float* rgb) {
    float h = hsv[0] / 60.0f;
    float s = hsv[1];
    float v = hsv[2];
    
    int i = static_cast<int>(std::floor(h));
    float f = h - i;
    float p = v * (1.0f - s);
    float q = v * (1.0f - s * f);
    float t = v * (1.0f - s * (1.0f - f));
    
    switch (i % 6) {
        case 0: rgb[0] = v; rgb[1] = t; rgb[2] = p; break;
        case 1: rgb[0] = q; rgb[1] = v; rgb[2] = p; break;
        case 2: rgb[0] = p; rgb[1] = v; rgb[2] = t; break;
        case 3: rgb[0] = p; rgb[1] = q; rgb[2] = v; break;
        case 4: rgb[0] = t; rgb[1] = p; rgb[2] = v; break;
        case 5: rgb[0] = v; rgb[1] = p; rgb[2] = q; break;
    }
}

} // namespace Math
} // namespace ShaderCandy
