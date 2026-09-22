/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#pragma once

/// @file MathUtils.h
/// @brief SIMD-accelerated math utilities for ShaderCandy.
/// @details Provides Vec2/Vec3/Vec4 types, dot/cross products, and dispatch wrappers
///          for NEON (ARM), AVX2 (x86), SSE (x86 fallback), and scalar fallbacks. Also includes
///          RGB<->HSV color space conversion and array batch operations.

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <initializer_list>

// SIMD feature detection and platform includes
#if defined(USE_NEON) || defined(__ARM_NEON)
#include <arm_neon.h>
#define SHADERCANDY_SIMD_NEON 1
#endif

#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
#if defined(USE_AVX2) || defined(__AVX2__)
#include <immintrin.h>
#define SHADERCANDY_SIMD_AVX2 1
#endif
#include <emmintrin.h>
#include <xmmintrin.h>
#if defined(__SSE4_1__)
#include <smmintrin.h>
#endif
#define SHADERCANDY_SIMD_SSE 1
#endif

namespace ShaderCandy {
namespace Math {

// Basic vector types
struct Vec2 {
  float x, y;
  Vec2(float x = 0, float y = 0) : x(x), y(y) {}

  float length() const { return std::sqrt(x * x + y * y); }
  float lengthSq() const { return x * x + y * y; }

  Vec2 normalize() const {
    float len = length();
    if (len > 0) {
      float inv = 1.0f / len;
      return Vec2(x * inv, y * inv);
    }
    return *this;
  }

  Vec2 operator+(const Vec2 &o) const { return Vec2(x + o.x, y + o.y); }
  Vec2 operator-(const Vec2 &o) const { return Vec2(x - o.x, y - o.y); }
  Vec2 operator*(float s) const { return Vec2(x * s, y * s); }
  Vec2 operator*(const Vec2 &o) const { return Vec2(x * o.x, y * o.y); }
  Vec2 operator/(float s) const { return Vec2(x / s, y / s); }
  Vec2 &operator+=(const Vec2 &o) { x += o.x; y += o.y; return *this; }
  Vec2 &operator-=(const Vec2 &o) { x -= o.x; y -= o.y; return *this; }
  Vec2 &operator*=(float s) { x *= s; y *= s; return *this; }
  bool operator==(const Vec2 &o) const { return x == o.x && y == o.y; }
  bool operator!=(const Vec2 &o) const { return !(*this == o); }
};

inline float dot(const Vec2 &a, const Vec2 &b) {
  return a.x * b.x + a.y * b.y;
}

struct Vec3 {
  float x, y, z;
  Vec3(float x = 0, float y = 0, float z = 0) : x(x), y(y), z(z) {}

  float length() const { return std::sqrt(x * x + y * y + z * z); }
  float lengthSq() const { return x * x + y * y + z * z; }

  Vec3 normalize() const {
    float len = length();
    if (len > 0) {
      float inv = 1.0f / len;
      return Vec3(x * inv, y * inv, z * inv);
    }
    return *this;
  }

  Vec3 operator+(const Vec3 &o) const {
    return Vec3(x + o.x, y + o.y, z + o.z);
  }
  Vec3 operator-(const Vec3 &o) const {
    return Vec3(x - o.x, y - o.y, z - o.z);
  }
  Vec3 operator*(float s) const { return Vec3(x * s, y * s, z * s); }
  Vec3 operator*(const Vec3 &o) const { return Vec3(x * o.x, y * o.y, z * o.z); }
  Vec3 operator/(float s) const { return Vec3(x / s, y / s, z / s); }
  Vec3 &operator+=(const Vec3 &o) { x += o.x; y += o.y; z += o.z; return *this; }
  Vec3 &operator-=(const Vec3 &o) { x -= o.x; y -= o.y; z -= o.z; return *this; }
  Vec3 &operator*=(float s) { x *= s; y *= s; z *= s; return *this; }
  bool operator==(const Vec3 &o) const { return x == o.x && y == o.y && z == o.z; }
  bool operator!=(const Vec3 &o) const { return !(*this == o); }
};

inline float dot(const Vec3 &a, const Vec3 &b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

inline Vec3 cross(const Vec3 &a, const Vec3 &b) {
  return Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z,
              a.x * b.y - a.y * b.x);
}

// SIMD-accelerated 4D Vector
struct alignas(16) Vec4 {
  float x, y, z, w;
  Vec4(float x = 0.0f, float y = 0.0f, float z = 0.0f, float w = 0.0f)
      : x(x), y(y), z(z), w(w) {}
  explicit Vec4(float v) : x(v), y(v), z(v), w(v) {}

  float lengthSq() const {
#if defined(SHADERCANDY_SIMD_SSE)
    __m128 v = _mm_loadu_ps(&x);
    __m128 mul = _mm_mul_ps(v, v);
    alignas(16) float r[4];
    _mm_store_ps(r, mul);
    return r[0] + r[1] + r[2] + r[3];
#elif defined(SHADERCANDY_SIMD_NEON)
    float32x4_t v = vld1q_f32(&x);
    float32x4_t mul = vmulq_f32(v, v);
    float r[4];
    vst1q_f32(r, mul);
    return r[0] + r[1] + r[2] + r[3];
#else
    return x * x + y * y + z * z + w * w;
#endif
  }

  float length() const { return std::sqrt(lengthSq()); }

  Vec4 normalize() const {
    float len = length();
    if (len > 0.0f) {
      float inv = 1.0f / len;
      return *this * inv;
    }
    return *this;
  }

  Vec4 operator+(const Vec4 &o) const {
#if defined(SHADERCANDY_SIMD_SSE)
    Vec4 res;
    __m128 va = _mm_loadu_ps(&x);
    __m128 vb = _mm_loadu_ps(&o.x);
    _mm_storeu_ps(&res.x, _mm_add_ps(va, vb));
    return res;
#elif defined(SHADERCANDY_SIMD_NEON)
    Vec4 res;
    float32x4_t va = vld1q_f32(&x);
    float32x4_t vb = vld1q_f32(&o.x);
    vst1q_f32(&res.x, vaddq_f32(va, vb));
    return res;
#else
    return Vec4(x + o.x, y + o.y, z + o.z, w + o.w);
#endif
  }

  Vec4 operator-(const Vec4 &o) const {
#if defined(SHADERCANDY_SIMD_SSE)
    Vec4 res;
    __m128 va = _mm_loadu_ps(&x);
    __m128 vb = _mm_loadu_ps(&o.x);
    _mm_storeu_ps(&res.x, _mm_sub_ps(va, vb));
    return res;
#elif defined(SHADERCANDY_SIMD_NEON)
    Vec4 res;
    float32x4_t va = vld1q_f32(&x);
    float32x4_t vb = vld1q_f32(&o.x);
    vst1q_f32(&res.x, vsubq_f32(va, vb));
    return res;
#else
    return Vec4(x - o.x, y - o.y, z - o.z, w - o.w);
#endif
  }

  Vec4 operator*(float s) const {
#if defined(SHADERCANDY_SIMD_SSE)
    Vec4 res;
    __m128 va = _mm_loadu_ps(&x);
    __m128 vs = _mm_set1_ps(s);
    _mm_storeu_ps(&res.x, _mm_mul_ps(va, vs));
    return res;
#elif defined(SHADERCANDY_SIMD_NEON)
    Vec4 res;
    float32x4_t va = vld1q_f32(&x);
    float32x4_t vs = vdupq_n_f32(s);
    vst1q_f32(&res.x, vmulq_f32(va, vs));
    return res;
#else
    return Vec4(x * s, y * s, z * s, w * s);
#endif
  }

  Vec4 operator*(const Vec4 &o) const {
#if defined(SHADERCANDY_SIMD_SSE)
    Vec4 res;
    __m128 va = _mm_loadu_ps(&x);
    __m128 vb = _mm_loadu_ps(&o.x);
    _mm_storeu_ps(&res.x, _mm_mul_ps(va, vb));
    return res;
#elif defined(SHADERCANDY_SIMD_NEON)
    Vec4 res;
    float32x4_t va = vld1q_f32(&x);
    float32x4_t vb = vld1q_f32(&o.x);
    vst1q_f32(&res.x, vmulq_f32(va, vb));
    return res;
#else
    return Vec4(x * o.x, y * o.y, z * o.z, w * o.w);
#endif
  }

  Vec4 operator/(float s) const { return *this * (1.0f / s); }
  Vec4 &operator+=(const Vec4 &o) { *this = *this + o; return *this; }
  Vec4 &operator-=(const Vec4 &o) { *this = *this - o; return *this; }
  Vec4 &operator*=(float s) { *this = *this * s; return *this; }
  Vec4 &operator*=(const Vec4 &o) { *this = *this * o; return *this; }
  Vec4 &operator/=(float s) { *this = *this / s; return *this; }
  bool operator==(const Vec4 &o) const {
    return x == o.x && y == o.y && z == o.z && w == o.w;
  }
  bool operator!=(const Vec4 &o) const { return !(*this == o); }
};

inline float dot(const Vec4 &a, const Vec4 &b) {
#if defined(SHADERCANDY_SIMD_SSE)
  __m128 va = _mm_loadu_ps(&a.x);
  __m128 vb = _mm_loadu_ps(&b.x);
  __m128 mul = _mm_mul_ps(va, vb);
  alignas(16) float r[4];
  _mm_store_ps(r, mul);
  return r[0] + r[1] + r[2] + r[3];
#elif defined(SHADERCANDY_SIMD_NEON)
  float32x4_t va = vld1q_f32(&a.x);
  float32x4_t vb = vld1q_f32(&b.x);
  float32x4_t mul = vmulq_f32(va, vb);
  float r[4];
  vst1q_f32(r, mul);
  return r[0] + r[1] + r[2] + r[3];
#else
  return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
#endif
}

// Graphics & Shader Math Primitives
inline Vec3 reflect(const Vec3 &incident, const Vec3 &normal) {
  return incident - normal * (2.0f * dot(normal, incident));
}

inline float clamp(float v, float minVal, float maxVal) {
  return std::max(minVal, std::min(maxVal, v));
}

inline Vec3 clamp(const Vec3 &v, float minVal, float maxVal) {
  return Vec3(clamp(v.x, minVal, maxVal),
              clamp(v.y, minVal, maxVal),
              clamp(v.z, minVal, maxVal));
}

inline Vec4 clamp(const Vec4 &v, float minVal, float maxVal) {
#if defined(SHADERCANDY_SIMD_SSE)
  Vec4 res;
  __m128 val = _mm_loadu_ps(&v.x);
  __m128 vmin = _mm_set1_ps(minVal);
  __m128 vmax = _mm_set1_ps(maxVal);
  __m128 clamped = _mm_max_ps(vmin, _mm_min_ps(vmax, val));
  _mm_storeu_ps(&res.x, clamped);
  return res;
#elif defined(SHADERCANDY_SIMD_NEON)
  Vec4 res;
  float32x4_t val = vld1q_f32(&v.x);
  float32x4_t vmin = vdupq_n_f32(minVal);
  float32x4_t vmax = vdupq_n_f32(maxVal);
  float32x4_t clamped = vmaxq_f32(vmin, vminq_f32(vmax, val));
  vst1q_f32(&res.x, clamped);
  return res;
#else
  return Vec4(clamp(v.x, minVal, maxVal), clamp(v.y, minVal, maxVal),
              clamp(v.z, minVal, maxVal), clamp(v.w, minVal, maxVal));
#endif
}

inline float saturate(float v) {
  return clamp(v, 0.0f, 1.0f);
}

inline Vec4 saturate(const Vec4 &v) {
  return clamp(v, 0.0f, 1.0f);
}

inline float mix(float a, float b, float t) {
  return a * (1.0f - t) + b * t;
}

inline Vec3 mix(const Vec3 &a, const Vec3 &b, float t) {
  return a * (1.0f - t) + b * t;
}

inline Vec4 mix(const Vec4 &a, const Vec4 &b, float t) {
  return a * (1.0f - t) + b * t;
}

inline float step(float edge, float x) {
  return x < edge ? 0.0f : 1.0f;
}

inline Vec4 step(float edge, const Vec4 &v) {
  return Vec4(step(edge, v.x), step(edge, v.y), step(edge, v.z), step(edge, v.w));
}

inline float smoothstep(float edge0, float edge1, float x) {
  if (edge0 >= edge1) return 0.0f;
  float t = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
  return t * t * (3.0f - 2.0f * t);
}

// Branchless math helpers
inline float branchlessSelect(bool cond, float trueVal, float falseVal) {
  return cond ? trueVal : falseVal;
}

inline float branchlessBounce(float pos, float vel, float minBound = -1.0f, float maxBound = 1.0f) {
  bool outOfBounds = (pos < minBound) || (pos > maxBound);
  return outOfBounds ? -vel : vel;
}

// GPU Buffer & Memory Alignment
inline size_t alignUp(size_t size, size_t alignment) {
  if (alignment == 0) return size;
  return (size + alignment - 1) & ~(alignment - 1);
}

// ============================================================================
// SIMD Operations - NEON (ARM)
// ============================================================================
#if defined(SHADERCANDY_SIMD_NEON)

inline void multiplyArrayNEON(float *dst, const float *a, const float *b, size_t count) {
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    float32x4_t va = vld1q_f32(&a[i]);
    float32x4_t vb = vld1q_f32(&b[i]);
    vst1q_f32(&dst[i], vmulq_f32(va, vb));
  }
  for (; i < count; i++) {
    dst[i] = a[i] * b[i];
  }
}

inline float sumArrayNEON(const float *data, size_t count) {
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

inline void lerpArrayNEON(float *dst, const float *a, const float *b, float t, size_t count) {
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

inline void scaleArrayNEON(float *dst, const float *src, float s, size_t count) {
  float32x4_t vs = vdupq_n_f32(s);
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    float32x4_t v = vld1q_f32(&src[i]);
    vst1q_f32(&dst[i], vmulq_f32(v, vs));
  }
  for (; i < count; i++) {
    dst[i] = src[i] * s;
  }
}

inline void addArrayNEON(float *dst, const float *a, const float *b, size_t count) {
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    float32x4_t va = vld1q_f32(&a[i]);
    float32x4_t vb = vld1q_f32(&b[i]);
    vst1q_f32(&dst[i], vaddq_f32(va, vb));
  }
  for (; i < count; i++) {
    dst[i] = a[i] + b[i];
  }
}

inline void clampArrayNEON(float *dst, const float *src, float minVal, float maxVal, size_t count) {
  float32x4_t vmin = vdupq_n_f32(minVal);
  float32x4_t vmax = vdupq_n_f32(maxVal);
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    float32x4_t v = vld1q_f32(&src[i]);
    float32x4_t vr = vmaxq_f32(vmin, vminq_f32(vmax, v));
    vst1q_f32(&dst[i], vr);
  }
  for (; i < count; i++) {
    dst[i] = std::max(minVal, std::min(maxVal, src[i]));
  }
}

inline float dotArrayNEON(const float *a, const float *b, size_t count) {
  float32x4_t acc = vdupq_n_f32(0.0f);
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    float32x4_t va = vld1q_f32(&a[i]);
    float32x4_t vb = vld1q_f32(&b[i]);
    acc = vmlaq_f32(acc, va, vb);
  }
  float result[4];
  vst1q_f32(result, acc);
  float total = result[0] + result[1] + result[2] + result[3];
  for (; i < count; i++) {
    total += a[i] * b[i];
  }
  return total;
}

inline void minMaxArrayNEON(const float *data, size_t count, float &outMin, float &outMax) {
  if (count == 0) {
    outMin = 0.0f;
    outMax = 0.0f;
    return;
  }
  float mn = data[0];
  float mx = data[0];
  size_t i = 0;
  if (count >= 4) {
    float32x4_t vmin = vdupq_n_f32(data[0]);
    float32x4_t vmax = vdupq_n_f32(data[0]);
    for (; i + 3 < count; i += 4) {
      float32x4_t v = vld1q_f32(&data[i]);
      vmin = vminq_f32(vmin, v);
      vmax = vmaxq_f32(vmax, v);
    }
    float rmin[4], rmax[4];
    vst1q_f32(rmin, vmin);
    vst1q_f32(rmax, vmax);
    mn = std::min({rmin[0], rmin[1], rmin[2], rmin[3]});
    mx = std::max({rmax[0], rmax[1], rmax[2], rmax[3]});
  }
  for (; i < count; i++) {
    mn = std::min(mn, data[i]);
    mx = std::max(mx, data[i]);
  }
  outMin = mn;
  outMax = mx;
}

inline void fmaArrayNEON(float *dst, const float *a, const float *b, const float *c, size_t count) {
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    float32x4_t va = vld1q_f32(&a[i]);
    float32x4_t vb = vld1q_f32(&b[i]);
    float32x4_t vc = vld1q_f32(&c[i]);
    vst1q_f32(&dst[i], vmlaq_f32(vc, va, vb));
  }
  for (; i < count; i++) {
    dst[i] = a[i] * b[i] + c[i];
  }
}

inline float sumAbsArrayNEON(const float *data, size_t count) {
  float32x4_t sum = vdupq_n_f32(0.0f);
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    float32x4_t v = vld1q_f32(&data[i]);
    sum = vaddq_f32(sum, vabsq_f32(v));
  }
  float result[4];
  vst1q_f32(result, sum);
  float total = result[0] + result[1] + result[2] + result[3];
  for (; i < count; i++) {
    total += std::abs(data[i]);
  }
  return total;
}

#endif // SHADERCANDY_SIMD_NEON

// ============================================================================
// SIMD Operations - SSE (x86 128-bit)
// ============================================================================
#if defined(SHADERCANDY_SIMD_SSE)

inline void multiplyArraySSE(float *dst, const float *a, const float *b, size_t count) {
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
    _mm_storeu_ps(&dst[i], _mm_mul_ps(va, vb));
  }
  for (; i < count; i++) {
    dst[i] = a[i] * b[i];
  }
}

inline float sumArraySSE(const float *data, size_t count) {
  __m128 sum = _mm_setzero_ps();
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&data[i]);
    sum = _mm_add_ps(sum, v);
  }
  alignas(16) float r[4];
  _mm_store_ps(r, sum);
  float total = r[0] + r[1] + r[2] + r[3];
  for (; i < count; i++) {
    total += data[i];
  }
  return total;
}

inline void lerpArraySSE(float *dst, const float *a, const float *b, float t, size_t count) {
  __m128 vt = _mm_set1_ps(t);
  __m128 v1t = _mm_set1_ps(1.0f - t);
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
#if defined(__FMA__)
    __m128 vr = _mm_fmadd_ps(vb, vt, _mm_mul_ps(va, v1t));
#else
    __m128 vr = _mm_add_ps(_mm_mul_ps(va, v1t), _mm_mul_ps(vb, vt));
#endif
    _mm_storeu_ps(&dst[i], vr);
  }
  for (; i < count; i++) {
    dst[i] = a[i] * (1.0f - t) + b[i] * t;
  }
}

inline void scaleArraySSE(float *dst, const float *src, float s, size_t count) {
  __m128 vs = _mm_set1_ps(s);
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&src[i]);
    _mm_storeu_ps(&dst[i], _mm_mul_ps(v, vs));
  }
  for (; i < count; i++) {
    dst[i] = src[i] * s;
  }
}

inline void addArraySSE(float *dst, const float *a, const float *b, size_t count) {
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
    _mm_storeu_ps(&dst[i], _mm_add_ps(va, vb));
  }
  for (; i < count; i++) {
    dst[i] = a[i] + b[i];
  }
}

inline void clampArraySSE(float *dst, const float *src, float minVal, float maxVal, size_t count) {
  __m128 vmin = _mm_set1_ps(minVal);
  __m128 vmax = _mm_set1_ps(maxVal);
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&src[i]);
    __m128 vr = _mm_max_ps(vmin, _mm_min_ps(vmax, v));
    _mm_storeu_ps(&dst[i], vr);
  }
  for (; i < count; i++) {
    dst[i] = std::max(minVal, std::min(maxVal, src[i]));
  }
}

inline float dotArraySSE(const float *a, const float *b, size_t count) {
  __m128 acc = _mm_setzero_ps();
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
#if defined(__FMA__)
    acc = _mm_fmadd_ps(va, vb, acc);
#else
    acc = _mm_add_ps(acc, _mm_mul_ps(va, vb));
#endif
  }
  alignas(16) float r[4];
  _mm_store_ps(r, acc);
  float total = r[0] + r[1] + r[2] + r[3];
  for (; i < count; i++) {
    total += a[i] * b[i];
  }
  return total;
}

inline void minMaxArraySSE(const float *data, size_t count, float &outMin, float &outMax) {
  if (count == 0) {
    outMin = 0.0f;
    outMax = 0.0f;
    return;
  }
  float mn = data[0];
  float mx = data[0];
  size_t i = 0;
  if (count >= 4) {
    __m128 vmin = _mm_set1_ps(data[0]);
    __m128 vmax = _mm_set1_ps(data[0]);
    for (; i + 3 < count; i += 4) {
      __m128 v = _mm_loadu_ps(&data[i]);
      vmin = _mm_min_ps(vmin, v);
      vmax = _mm_max_ps(vmax, v);
    }
    alignas(16) float rmin[4], rmax[4];
    _mm_store_ps(rmin, vmin);
    _mm_store_ps(rmax, vmax);
    mn = std::min({rmin[0], rmin[1], rmin[2], rmin[3]});
    mx = std::max({rmax[0], rmax[1], rmax[2], rmax[3]});
  }
  for (; i < count; i++) {
    mn = std::min(mn, data[i]);
    mx = std::max(mx, data[i]);
  }
  outMin = mn;
  outMax = mx;
}

inline void fmaArraySSE(float *dst, const float *a, const float *b, const float *c, size_t count) {
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
    __m128 vc = _mm_loadu_ps(&c[i]);
#if defined(__FMA__)
    _mm_storeu_ps(&dst[i], _mm_fmadd_ps(va, vb, vc));
#else
    _mm_storeu_ps(&dst[i], _mm_add_ps(_mm_mul_ps(va, vb), vc));
#endif
  }
  for (; i < count; i++) {
    dst[i] = a[i] * b[i] + c[i];
  }
}

inline float sumAbsArraySSE(const float *data, size_t count) {
  __m128 sum = _mm_setzero_ps();
  __m128 sign_mask = _mm_castsi128_ps(_mm_set1_epi32(0x7fffffff));
  size_t i = 0;
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&data[i]);
    sum = _mm_add_ps(sum, _mm_and_ps(v, sign_mask));
  }
  alignas(16) float r[4];
  _mm_store_ps(r, sum);
  float total = r[0] + r[1] + r[2] + r[3];
  for (; i < count; i++) {
    total += std::abs(data[i]);
  }
  return total;
}

#endif // SHADERCANDY_SIMD_SSE

// ============================================================================
// SIMD Operations - AVX2 (x86 256-bit)
// ============================================================================
#if defined(SHADERCANDY_SIMD_AVX2)

inline void multiplyArrayAVX2(float *dst, const float *a, const float *b, size_t count) {
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 va = _mm256_loadu_ps(&a[i]);
    __m256 vb = _mm256_loadu_ps(&b[i]);
    _mm256_storeu_ps(&dst[i], _mm256_mul_ps(va, vb));
  }
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
    _mm_storeu_ps(&dst[i], _mm_mul_ps(va, vb));
  }
  for (; i < count; i++) {
    dst[i] = a[i] * b[i];
  }
}

inline float sumArrayAVX2(const float *data, size_t count) {
  __m256 sum = _mm256_setzero_ps();
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 v = _mm256_loadu_ps(&data[i]);
    sum = _mm256_add_ps(sum, v);
  }
  __m128 sum128 = _mm_add_ps(_mm256_castps256_ps128(sum), _mm256_extractf128_ps(sum, 1));
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&data[i]);
    sum128 = _mm_add_ps(sum128, v);
  }
  alignas(16) float r[4];
  _mm_store_ps(r, sum128);
  float total = r[0] + r[1] + r[2] + r[3];
  for (; i < count; i++) {
    total += data[i];
  }
  return total;
}

inline void lerpArrayAVX2(float *dst, const float *a, const float *b, float t, size_t count) {
  __m256 vt = _mm256_set1_ps(t);
  __m256 v1t = _mm256_set1_ps(1.0f - t);
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 va = _mm256_loadu_ps(&a[i]);
    __m256 vb = _mm256_loadu_ps(&b[i]);
#if defined(__FMA__)
    __m256 vr = _mm256_fmadd_ps(vb, vt, _mm256_mul_ps(va, v1t));
#else
    __m256 vr = _mm256_add_ps(_mm256_mul_ps(va, v1t), _mm256_mul_ps(vb, vt));
#endif
    _mm256_storeu_ps(&dst[i], vr);
  }
  __m128 vt128 = _mm_set1_ps(t);
  __m128 v1t128 = _mm_set1_ps(1.0f - t);
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
#if defined(__FMA__)
    __m128 vr = _mm_fmadd_ps(vb, vt128, _mm_mul_ps(va, v1t128));
#else
    __m128 vr = _mm_add_ps(_mm_mul_ps(va, v1t128), _mm_mul_ps(vb, vt128));
#endif
    _mm_storeu_ps(&dst[i], vr);
  }
  for (; i < count; i++) {
    dst[i] = a[i] * (1.0f - t) + b[i] * t;
  }
}

inline void scaleArrayAVX2(float *dst, const float *src, float s, size_t count) {
  __m256 vs = _mm256_set1_ps(s);
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 v = _mm256_loadu_ps(&src[i]);
    _mm256_storeu_ps(&dst[i], _mm256_mul_ps(v, vs));
  }
  __m128 vs128 = _mm_set1_ps(s);
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&src[i]);
    _mm_storeu_ps(&dst[i], _mm_mul_ps(v, vs128));
  }
  for (; i < count; i++) {
    dst[i] = src[i] * s;
  }
}

inline void addArrayAVX2(float *dst, const float *a, const float *b, size_t count) {
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 va = _mm256_loadu_ps(&a[i]);
    __m256 vb = _mm256_loadu_ps(&b[i]);
    _mm256_storeu_ps(&dst[i], _mm256_add_ps(va, vb));
  }
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
    _mm_storeu_ps(&dst[i], _mm_add_ps(va, vb));
  }
  for (; i < count; i++) {
    dst[i] = a[i] + b[i];
  }
}

inline void clampArrayAVX2(float *dst, const float *src, float minVal, float maxVal, size_t count) {
  __m256 vmin = _mm256_set1_ps(minVal);
  __m256 vmax = _mm256_set1_ps(maxVal);
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 v = _mm256_loadu_ps(&src[i]);
    __m256 vr = _mm256_max_ps(vmin, _mm256_min_ps(vmax, v));
    _mm256_storeu_ps(&dst[i], vr);
  }
  __m128 vmin128 = _mm_set1_ps(minVal);
  __m128 vmax128 = _mm_set1_ps(maxVal);
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&src[i]);
    __m128 vr = _mm_max_ps(vmin128, _mm_min_ps(vmax128, v));
    _mm_storeu_ps(&dst[i], vr);
  }
  for (; i < count; i++) {
    dst[i] = std::max(minVal, std::min(maxVal, src[i]));
  }
}

inline float dotArrayAVX2(const float *a, const float *b, size_t count) {
  __m256 acc = _mm256_setzero_ps();
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 va = _mm256_loadu_ps(&a[i]);
    __m256 vb = _mm256_loadu_ps(&b[i]);
#if defined(__FMA__)
    acc = _mm256_fmadd_ps(va, vb, acc);
#else
    acc = _mm256_add_ps(acc, _mm256_mul_ps(va, vb));
#endif
  }
  __m128 acc128 = _mm_add_ps(_mm256_castps256_ps128(acc), _mm256_extractf128_ps(acc, 1));
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
#if defined(__FMA__)
    acc128 = _mm_fmadd_ps(va, vb, acc128);
#else
    acc128 = _mm_add_ps(acc128, _mm_mul_ps(va, vb));
#endif
  }
  alignas(16) float r[4];
  _mm_store_ps(r, acc128);
  float total = r[0] + r[1] + r[2] + r[3];
  for (; i < count; i++) {
    total += a[i] * b[i];
  }
  return total;
}

inline void minMaxArrayAVX2(const float *data, size_t count, float &outMin, float &outMax) {
  if (count == 0) {
    outMin = 0.0f;
    outMax = 0.0f;
    return;
  }
  float mn = data[0];
  float mx = data[0];
  size_t i = 0;
  if (count >= 8) {
    __m256 vmin = _mm256_set1_ps(data[0]);
    __m256 vmax = _mm256_set1_ps(data[0]);
    for (; i + 7 < count; i += 8) {
      __m256 v = _mm256_loadu_ps(&data[i]);
      vmin = _mm256_min_ps(vmin, v);
      vmax = _mm256_max_ps(vmax, v);
    }
    __m128 vmin128 = _mm_min_ps(_mm256_castps256_ps128(vmin), _mm256_extractf128_ps(vmin, 1));
    __m128 vmax128 = _mm_max_ps(_mm256_castps256_ps128(vmax), _mm256_extractf128_ps(vmax, 1));
    alignas(16) float rmin[4], rmax[4];
    _mm_store_ps(rmin, vmin128);
    _mm_store_ps(rmax, vmax128);
    mn = std::min({rmin[0], rmin[1], rmin[2], rmin[3]});
    mx = std::max({rmax[0], rmax[1], rmax[2], rmax[3]});
  }
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&data[i]);
    __m128 vmin128 = _mm_set1_ps(mn);
    __m128 vmax128 = _mm_set1_ps(mx);
    vmin128 = _mm_min_ps(vmin128, v);
    vmax128 = _mm_max_ps(vmax128, v);
    alignas(16) float rmin[4], rmax[4];
    _mm_store_ps(rmin, vmin128);
    _mm_store_ps(rmax, vmax128);
    mn = std::min({rmin[0], rmin[1], rmin[2], rmin[3]});
    mx = std::max({rmax[0], rmax[1], rmax[2], rmax[3]});
  }
  for (; i < count; i++) {
    mn = std::min(mn, data[i]);
    mx = std::max(mx, data[i]);
  }
  outMin = mn;
  outMax = mx;
}

inline void fmaArrayAVX2(float *dst, const float *a, const float *b, const float *c, size_t count) {
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 va = _mm256_loadu_ps(&a[i]);
    __m256 vb = _mm256_loadu_ps(&b[i]);
    __m256 vc = _mm256_loadu_ps(&c[i]);
#if defined(__FMA__)
    _mm256_storeu_ps(&dst[i], _mm256_fmadd_ps(va, vb, vc));
#else
    _mm256_storeu_ps(&dst[i], _mm256_add_ps(_mm256_mul_ps(va, vb), vc));
#endif
  }
  for (; i + 3 < count; i += 4) {
    __m128 va = _mm_loadu_ps(&a[i]);
    __m128 vb = _mm_loadu_ps(&b[i]);
    __m128 vc = _mm_loadu_ps(&c[i]);
#if defined(__FMA__)
    _mm_storeu_ps(&dst[i], _mm_fmadd_ps(va, vb, vc));
#else
    _mm_storeu_ps(&dst[i], _mm_add_ps(_mm_mul_ps(va, vb), vc));
#endif
  }
  for (; i < count; i++) {
    dst[i] = a[i] * b[i] + c[i];
  }
}

inline float sumAbsArrayAVX2(const float *data, size_t count) {
  __m256 sum = _mm256_setzero_ps();
  __m256 sign_mask = _mm256_castsi256_ps(_mm256_set1_epi32(0x7fffffff));
  size_t i = 0;
  for (; i + 7 < count; i += 8) {
    __m256 v = _mm256_loadu_ps(&data[i]);
    sum = _mm256_add_ps(sum, _mm256_and_ps(v, sign_mask));
  }
  __m128 sum128 = _mm_add_ps(_mm256_castps256_ps128(sum), _mm256_extractf128_ps(sum, 1));
  __m128 sign_mask128 = _mm_castsi128_ps(_mm_set1_epi32(0x7fffffff));
  for (; i + 3 < count; i += 4) {
    __m128 v = _mm_loadu_ps(&data[i]);
    sum128 = _mm_add_ps(sum128, _mm_and_ps(v, sign_mask128));
  }
  alignas(16) float r[4];
  _mm_store_ps(r, sum128);
  float total = r[0] + r[1] + r[2] + r[3];
  for (; i < count; i++) {
    total += std::abs(data[i]);
  }
  return total;
}

#endif // SHADERCANDY_SIMD_AVX2

// ============================================================================
// Generic Dispatches
// ============================================================================
inline void multiplyArray(float *dst, const float *a, const float *b, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  multiplyArrayAVX2(dst, a, b, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  multiplyArraySSE(dst, a, b, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  multiplyArrayNEON(dst, a, b, count);
#else
  for (size_t i = 0; i < count; i++) {
    dst[i] = a[i] * b[i];
  }
#endif
}

inline float sumArray(const float *data, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  return sumArrayAVX2(data, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  return sumArraySSE(data, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  return sumArrayNEON(data, count);
#else
  float sum = 0.0f;
  for (size_t i = 0; i < count; i++) {
    sum += data[i];
  }
  return sum;
#endif
}

inline void lerpArray(float *dst, const float *a, const float *b, float t, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  lerpArrayAVX2(dst, a, b, t, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  lerpArraySSE(dst, a, b, t, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  lerpArrayNEON(dst, a, b, t, count);
#else
  for (size_t i = 0; i < count; i++) {
    dst[i] = a[i] * (1.0f - t) + b[i] * t;
  }
#endif
}

inline void scaleArray(float *dst, const float *src, float s, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  scaleArrayAVX2(dst, src, s, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  scaleArraySSE(dst, src, s, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  scaleArrayNEON(dst, src, s, count);
#else
  for (size_t i = 0; i < count; i++) {
    dst[i] = src[i] * s;
  }
#endif
}

inline void addArray(float *dst, const float *a, const float *b, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  addArrayAVX2(dst, a, b, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  addArraySSE(dst, a, b, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  addArrayNEON(dst, a, b, count);
#else
  for (size_t i = 0; i < count; i++) {
    dst[i] = a[i] + b[i];
  }
#endif
}

inline void clampArray(float *dst, const float *src, float minVal, float maxVal, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  clampArrayAVX2(dst, src, minVal, maxVal, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  clampArraySSE(dst, src, minVal, maxVal, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  clampArrayNEON(dst, src, minVal, maxVal, count);
#else
  for (size_t i = 0; i < count; i++) {
    dst[i] = std::max(minVal, std::min(maxVal, src[i]));
  }
#endif
}

inline float dotArray(const float *a, const float *b, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  return dotArrayAVX2(a, b, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  return dotArraySSE(a, b, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  return dotArrayNEON(a, b, count);
#else
  float dotProduct = 0.0f;
  for (size_t i = 0; i < count; i++) {
    dotProduct += a[i] * b[i];
  }
  return dotProduct;
#endif
}

inline void minMaxArray(const float *data, size_t count, float &outMin, float &outMax) {
#if defined(SHADERCANDY_SIMD_AVX2)
  minMaxArrayAVX2(data, count, outMin, outMax);
#elif defined(SHADERCANDY_SIMD_SSE)
  minMaxArraySSE(data, count, outMin, outMax);
#elif defined(SHADERCANDY_SIMD_NEON)
  minMaxArrayNEON(data, count, outMin, outMax);
#else
  if (count == 0) {
    outMin = 0.0f;
    outMax = 0.0f;
    return;
  }
  float mn = data[0];
  float mx = data[0];
  for (size_t i = 1; i < count; i++) {
    mn = std::min(mn, data[i]);
    mx = std::max(mx, data[i]);
  }
  outMin = mn;
  outMax = mx;
#endif
}

inline void fmaArray(float *dst, const float *a, const float *b, const float *c, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  fmaArrayAVX2(dst, a, b, c, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  fmaArraySSE(dst, a, b, c, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  fmaArrayNEON(dst, a, b, c, count);
#else
  for (size_t i = 0; i < count; i++) {
    dst[i] = a[i] * b[i] + c[i];
  }
#endif
}

inline float sumAbsArray(const float *data, size_t count) {
#if defined(SHADERCANDY_SIMD_AVX2)
  return sumAbsArrayAVX2(data, count);
#elif defined(SHADERCANDY_SIMD_SSE)
  return sumAbsArraySSE(data, count);
#elif defined(SHADERCANDY_SIMD_NEON)
  return sumAbsArrayNEON(data, count);
#else
  float sum = 0.0f;
  for (size_t i = 0; i < count; i++) {
    sum += std::abs(data[i]);
  }
  return sum;
#endif
}

// Color space conversion
inline void rgbToHsv(const float *rgb, float *hsv) {
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

inline void hsvToRgb(const float *hsv, float *rgb) {
  float h = hsv[0] / 60.0f;
  float s = hsv[1];
  float v = hsv[2];

  int i = static_cast<int>(std::floor(h));
  float f = h - i;
  float p = v * (1.0f - s);
  float q = v * (1.0f - s * f);
  float t = v * (1.0f - s * (1.0f - f));

  switch (i % 6) {
  case 0:
    rgb[0] = v;
    rgb[1] = t;
    rgb[2] = p;
    break;
  case 1:
    rgb[0] = q;
    rgb[1] = v;
    rgb[2] = p;
    break;
  case 2:
    rgb[0] = p;
    rgb[1] = v;
    rgb[2] = t;
    break;
  case 3:
    rgb[0] = p;
    rgb[1] = q;
    rgb[2] = v;
    break;
  case 4:
    rgb[0] = t;
    rgb[1] = p;
    rgb[2] = v;
    break;
  case 5:
    rgb[0] = v;
    rgb[1] = p;
    rgb[2] = q;
    break;
  }
}

// Batch color conversions
inline void batchRgbToHsv(const float *rgb, float *hsv, size_t count) {
  for (size_t i = 0; i < count; i++) {
    rgbToHsv(&rgb[i * 3], &hsv[i * 3]);
  }
}

inline void batchHsvToRgb(const float *hsv, float *rgb, size_t count) {
  for (size_t i = 0; i < count; i++) {
    hsvToRgb(&hsv[i * 3], &rgb[i * 3]);
  }
}

} // namespace Math
} // namespace ShaderCandy
