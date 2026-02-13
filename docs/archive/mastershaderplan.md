# Master Shader Plan: Cross-Platform Eye-Candy Screensavers

## 📍 Project Status & Verified Completion (Updated: Feb 2026)

This document is the consolidated master plan for ShaderCandy. Detailed implementation history can be found in [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md), [PHASE2_SUMMARY.md](./PHASE2_SUMMARY.md), and [PHASE3_SUMMARY.md](./PHASE3_SUMMARY.md).

### ✅ Phase 1: Foundation (DONE)

- **Architecture**: Core abstraction layer, directory hierarchy, and CMake build system.
- **Backends**: Unified `Uniforms` structure and base shader frameworks (Metal/GLSL).
- **Core Logic**: Uniform management, performance monitoring, and hot-reload foundations.
- **Initial Effects**: Nebula, Mandelbulb, Reaction-Diffusion (GLSL/Metal).

### ✅ Phase 2: Platform & Features (DONE)

- **macOS Integration**: Native `ScreenSaverView` with Metal-backed `MTKView`.
- **Metal Renderer**: Triple-buffered uniform updates, optimized pipeline states.
- **Testing**: Unified Test Framework with SIMD (NEON/AVX2) and Compilation tests.
- **CI/CD**: GitHub Actions for automated builds for Linux and macOS.

### 🚧 Phase 3: Interaction & Polish (IN PROGRESS)

- **Interactive Particles**: [x] GPU Compute particle system with 50,000+ points.
- **Interactive Physics**: [x] Left-click (Pull) and Right-click (Push) gravitational forces.
- **Shader Preset System**: [x] Curated presets (Zen, Cosmic, Chaos, Vortex) with persistence.
- **Global Control UI**: [x] Sliders for Speed, Intensity, and Gravity in the config sheet.
- **Visual Polish**: [x] Smooth 2-second cross-fade shader transitions.
- **Optimization**: [x] Branchless shader logic for maximum GPU throughput.
- **Audio Reactivity**: [ ] Implementation of `AudioInput.mm` (Planned).
- **Multi-Monitor**: [ ] Synchronization across multiple screens (Planned).

---

## Part 1: Project Architecture & Directory Structure

### 1.1 Directory Layout

```
ShaderCandy/
├── src/
│   ├── metal/              # Apple Metal shaders (.metal)
│   ├── glsl/               # OpenGL/Vulkan shaders (.glsl, .frag, .vert)
│   ├── cuda/               # NVIDIA CUDA kernels (.cu) - optional compute
│   ├── core/               # Shared C++ abstraction layer
│   ├── platform/
│   │   ├── macos/          # macOS-specific implementation
│   │   └── linux/          # Linux-specific implementation
│   └── screensavers/       # Screen saver application entry points
├── shaders/
│   ├── base/               # Base framework shaders
│   ├── effects/            # Visual effect shaders
│   └── examples/           # Example implementations
├── docs/                   # Documentation
├── tools/                  # Build scripts and utilities
├── tests/                  # Performance and correctness tests
└── install/                # Installation scripts
```

### 1.2 Build System

- **macOS**: Xcode projects + CMake for Metal
- **Linux**: CMake + Ninja with OpenGL/Vulkan support
- **Cross-platform**: CMake 3.20+ with conditional compilation

---

## Part 2: Base Shader Framework

### 2.1 Core Shader Interface

**Metal Base Template** (`shaders/base/base.metal`):

```metal
#include <metal_stdlib>
using namespace metal;

// Uniform buffer for time, resolution, mouse
struct Uniforms {
    float time;
    float2 resolution;
    float2 mouse;
    float4 date;        // year, month, day, time in seconds
    int frame;
};

// Vertex shader - standard fullscreen quad
vertex float4 vertex_main(uint vertexID [[vertex_id]],
                         constant float2 *vertices [[buffer(0)]]) {
    return float4(vertices[vertexID], 0.0, 1.0);
}

// Fragment shader interface
fragment float4 fragment_main(float4 position [[position]],
                             constant Uniforms &uniforms [[buffer(0)]],
                             texture2d<float> prevFrame [[texture(0)]],
                             sampler frameSampler [[sampler(0)]]) {
    float2 uv = position.xy / uniforms.resolution;
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= uniforms.resolution.x / uniforms.resolution.y;
    
    // Base effect - returns color
    return effect_main(centered, uv, uniforms, prevFrame, frameSampler);
}
```

**GLSL Base Template** (`shaders/base/base.frag`):

```glsl
#version 450 core

layout(location = 0) in vec2 vUV;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform Uniforms {
    float time;
    vec2 resolution;
    vec2 mouse;
    vec4 date;
    int frame;
};

layout(binding = 1) uniform sampler2D prevFrame;

// Main effect function - to be implemented by specific shaders
vec4 effect_main(vec2 centered, vec2 uv);

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    vec2 centered = uv * 2.0 - 1.0;
    centered.x *= resolution.x / resolution.y;
    
    fragColor = effect_main(centered, uv);
}
```

### 2.2 Shader Hot-Reload System

- File watchers for automatic recompilation
- Runtime shader compilation on both platforms
- Error fallback to previous working shader

---

## Part 3: SIMD Optimizations

### 3.1 Metal SIMD (SIMD Library)

**Vector Types**:

- Use `float4`, `float3`, `float2` for all vector operations
- Leverage `simd_min`, `simd_max`, `simd_clamp` for vectorized math

**Example: SIMD Noise Generation**:

```metal
#include <simd/simd.h>

// SIMD-friendly hash function
inline float4 hash4(float4 p) {
    float4 r = fract(p * 0.1031);
    r += dot(r, float4(r.y + 33.33, r.z + 33.33, r.x + 33.33, r.w + 33.33));
    return fract((float4(r.x, r.x, r.y, r.y) + 
                  float4(r.y, r.z, r.z, r.x)) * 
                 float4(r.z, r.w, r.w, r.z));
}

// SIMD Perlin-like noise
float4 simdNoise4(float4 x) {
    float4 i = floor(x);
    float4 f = fract(x);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep
    
    float4 a = hash4(i);
    float4 b = hash4(i + 1.0);
    
    return mix(a, b, f);
}
```

### 3.2 GLSL SIMD via Vectorization

**Batch Operations**:

```glsl
// Process multiple samples at once using vec4
vec4 simdDistance(vec4 x, vec4 y, vec2 center) {
    vec4 dx = x - center.x;
    vec4 dy = y - center.y;
    return sqrt(dx * dx + dy * dy);
}

// Unroll loops for better vectorization
#pragma unroll
for (int i = 0; i < 4; i++) {
    color += sampleOffset(offsets[i]);
}
```

### 3.3 CPU-Side SIMD (Optional Compute)

**ARM NEON** (Apple Silicon):

```cpp
#include <arm_neon.h>

// NEON-accelerated particle updates
void updateParticlesNEON(Particle* particles, int count, float dt) {
    float32x4_t dt_vec = vdupq_n_f32(dt);
    
    for (int i = 0; i < count; i += 4) {
        float32x4x4_t pos = vld4q_f32((float*)&particles[i].position);
        float32x4x4_t vel = vld4q_f32((float*)&particles[i].velocity);
        
        // pos += vel * dt
        pos.val[0] = vmlaq_f32(pos.val[0], vel.val[0], dt_vec);
        pos.val[1] = vmlaq_f32(pos.val[1], vel.val[1], dt_vec);
        
        vst4q_f32((float*)&particles[i].position, pos);
    }
}
```

**x86 AVX2** (Intel/NVIDIA):

```cpp
#include <immintrin.h>

// AVX2-accelerated color space conversion
void convertRGBtoHSV_AVX2(const float* rgb, float* hsv, int count) {
    for (int i = 0; i < count; i += 8) {
        __m256 r = _mm256_load_ps(&rgb[i * 3]);
        __m256 g = _mm256_load_ps(&rgb[i * 3 + 8]);
        __m256 b = _mm256_load_ps(&rgb[i * 3 + 16]);
        
        // SIMD color conversion logic
        // ... HSV calculation using AVX2 intrinsics
    }
}
```

---

## Part 4: GPU Architecture Optimizations

### 4.1 Apple Metal Optimizations

**Tile-Based Deferred Rendering (TBDR)**:

```metal
// Use tile shaders for post-processing
kernel void tilePostProcess(
    texture2d<float, access::read_write> output [[texture(0)]],
    ushort2 gid [[thread_position_in_grid]],
    ushort2 tid [[thread_position_in_threadgroup]])
{
    // Tile-local operations reduce memory bandwidth
    threadgroup float4 tileData[32][32];
    tileData[tid.x][tid.y] = output.read(gid);
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Process within tile
    float4 color = tileData[tid.x][tid.y];
    // Apply effects using neighboring tile data
    output.write(color, gid);
}
```

**Memory Bandwidth Optimization**:

```metal
// Use half-precision where possible
using half4 = vector<half, 4>;

half4 fastEffect(half2 uv, constant Uniforms &u) {
    // Half-precision math is 2x faster on Apple GPUs
    half t = half(u.time);
    half4 color = half4(sin(t), cos(t), sin(t * 0.5), 1.0);
    return color;
}
```

**Threadgroup Memory**:

```metal
// Shared memory for compute shaders
constant int TILE_SIZE = 16;

kernel void blurHorizontal(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    ushort2 gid [[thread_position_in_grid]],
    ushort2 tid [[thread_position_in_threadgroup]])
{
    threadgroup float4 shared[TILE_SIZE + 8]; // Halo region
    
    // Load data cooperatively
    shared[tid.x] = input.read(gid);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Blur using shared memory
    float4 sum = 0.0;
    for (int i = -4; i <= 4; i++) {
        sum += shared[tid.x + i];
    }
    output.write(sum / 9.0, gid);
}
```

### 4.2 NVIDIA GPU Optimizations

**Warp-Level Primitives**:

```glsl
#extension GL_NV_shader_thread_group : require

// Use warp shuffle for inter-thread communication
vec4 warpReduce(vec4 val) {
    val += shuffleXorNV(val, 16);
    val += shuffleXorNV(val, 8);
    val += shuffleXorNV(val, 4);
    val += shuffleXorNV(val, 2);
    val += shuffleXorNV(val, 1);
    return val;
}
```

**Cooperative Groups**:

```cuda
#include <cooperative_groups.h>

namespace cg = cooperative_groups;

__global__ void particleSystem(Particle* particles, int n, float dt) {
    cg::thread_block block = cg::this_thread_block();
    
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n) return;
    
    // Synchronize within block for shared memory
    cg::sync(block);
    
    // Process particles with coalesced memory access
    Particle p = particles[idx];
    p.position += p.velocity * dt;
    particles[idx] = p;
}
```

**Tensor Core Utilization** (RTX GPUs):

```glsl
#extension GL_NV_cooperative_matrix : require

// Use tensor cores for matrix operations in ML-based effects
coopmat<float, gl_ScopeSubgroup, 16, 16, gl_MatrixUseA> matA;
coopmat<float, gl_ScopeSubgroup, 16, 16, gl_MatrixUseB> matB;
coopmat<float, gl_ScopeSubgroup, 16, 16, gl_MatrixUseAccumulator> matC;

// matC = matA * matB + matC using tensor cores
coopMatMulAdd(matA, matB, matC);
```

### 4.3 Memory Access Patterns

**Coalesced Memory Access**:

```metal
// Good: Sequential access pattern
kernel void goodAccess(
    device float4* input [[buffer(0)]],
    device float4* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]])
{
    output[gid] = process(input[gid]);
}

// Bad: Scattered access
kernel void badAccess(
    device float4* input [[buffer(0)]],
    device float4* output [[buffer(1)]],
    device uint* indices [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    uint idx = indices[gid]; // Non-coalesced
    output[gid] = process(input[idx]);
}
```

**Texture Sampling Optimization**:

```metal
// Use mipmaps for minification
constexpr sampler textureSampler(
    coord::normalized,
    filter::linear,
    mip_filter::linear,
    address::clamp_to_edge,
    max_anisotropy(8)
);

// Prefetch textures
float4 color = prevFrame.sample(textureSampler, uv, level(mipLevel));
```

---

## Part 5: Example Shaders - Building Blocks

### 5.1 Fractal Noise (Base for Many Effects)

**Metal Version**:

```metal
// Simplex noise - foundation for organic effects
float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float4 mod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
float4 permute(float4 x) { return mod289(((x * 34.0) + 1.0) * x); }
float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(float3 v) {
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
float fbm(float3 x, int octaves) {
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
```

### 5.2 Ray Marching Foundation

**Metal Signed Distance Functions (SDF)**:

```metal
// Basic SDF primitives
float sdSphere(float3 p, float r) {
    return length(p) - r;
}

float sdBox(float3 p, float3 b) {
    float3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdTorus(float3 p, float2 t) {
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// SDF operations
float opUnion(float d1, float d2) { return min(d1, d2); }
float opSubtraction(float d1, float d2) { return max(-d1, d2); }
float opIntersection(float d1, float d2) { return max(d1, d2); }

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Scene definition
float map(float3 p) {
    float d = sdSphere(p - float3(0.0, 0.0, 0.0), 1.0);
    d = opSmoothUnion(d, sdBox(p - float3(1.5, 0.0, 0.0), float3(0.5)), 0.3);
    return d;
}

// Ray marching
float3 rayMarch(float3 ro, float3 rd) {
    float t = 0.0;
    for (int i = 0; i < 100; i++) {
        float3 p = ro + t * rd;
        float d = map(p);
        if (d < 0.001 || t > 100.0) break;
        t += d;
    }
    return ro + t * rd;
}
```

### 5.3 Particle System Base

**Metal Compute Shader Particles**:

```metal
struct Particle {
    float3 position;
    float3 velocity;
    float4 color;
    float life;
    float size;
};

kernel void particleUpdate(
    device Particle* particles [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]],
    uint gid [[thread_position_in_grid]])
{
    Particle p = particles[gid];
    
    // Update physics
    p.velocity.y -= 0.1 * uniforms.time; // Gravity
    p.position += p.velocity * 0.016; // 60fps delta
    p.life -= 0.01;
    
    // Respawn if dead
    if (p.life <= 0.0) {
        p.position = float3(0.0);
        p.velocity = float3(
            (fract(sin(gid) * 43758.5453) - 0.5) * 2.0,
            fract(sin(gid + 1.0) * 43758.5453) * 2.0,
            (fract(sin(gid + 2.0) * 43758.5453) - 0.5) * 2.0
        );
        p.life = 1.0;
    }
    
    particles[gid] = p;
}
```

### 5.4 Post-Processing Stack

**Bloom Effect**:

```metal
// Downsample + Gaussian blur
kernel void bloomDownsample(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    float2 texel = 1.0 / float2(input.get_width(), input.get_height());
    
    // 4x4 tent filter
    float4 color = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            color += input.read(gid * 2 + uint2(x, y));
        }
    }
    
    output.write(color / 9.0, gid);
}

// Combine with tone mapping
kernel void bloomCombine(
    texture2d<float, access::read> scene [[texture(0)]],
    texture2d<float, access::read> bloom [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant float &intensity [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    float4 c = scene.read(gid);
    float4 b = bloom.read(uint2(gid / 4)); // Bloom is 1/4 resolution
    
    // Additive blend
    output.write(c + b * intensity, gid);
}
```

---

## Part 6: Platform-Specific Screensaver Implementations

### 6.1 macOS Screensaver Bundle

**Structure**:

```
ShaderCandy.saver/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── ShaderCandy      # Binary
│   └── Resources/
│       ├── shaders.metallib
│       ├── default.glsl
│       └── icon.icns
```

**Swift Screensaver Class**:

```swift
import ScreenSaver
import Metal
import MetalKit

class ShaderCandyView: ScreenSaverView {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var texture: MTLTexture!
    
    var startTime: Date!
    var frameCount: Int = 0
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        initializeMetal()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initializeMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        // Load shaders
        let library = try! device.makeDefaultLibrary()
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        // Create pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Fullscreen quad vertices
        let vertices: [Float] = [
            -1, -1,  1, -1,  -1, 1,
            -1,  1,  1, -1,   1, 1
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, 
                                         length: vertices.count * MemoryLayout<Float>.size)
        
        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size,
                                          options: .storageModeShared)
        
        startTime = Date()
    }
    
    override func draw(_ rect: NSRect) {
        // Update uniforms
        var uniforms = Uniforms()
        uniforms.time = Float(Date().timeIntervalSince(startTime))
        uniforms.resolution = SIMD2<Float>(Float(bounds.width), Float(bounds.height))
        uniforms.frame = frameCount
        
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
        
        // Render
        guard let drawable = (self as? MTKView)?.currentDrawable else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        frameCount += 1
    }
    
    override var hasConfigureSheet: Bool { return false }
    override var configureSheet: NSWindow? { return nil }
}
```

### 6.2 Linux X11 Screensaver

**Basic X11 + OpenGL Implementation**:

```cpp
// src/platform/linux/screensaver.cpp
#include <X11/Xlib.h>
#include <GL/glx.h>
#include <GL/gl.h>
#include <unistd.h>
#include <signal.h>

class X11ShaderScreensaver {
private:
    Display* display;
    Window window;
    GLXContext context;
    GLuint shaderProgram;
    GLuint vao, vbo;
    
public:
    X11ShaderScreensaver() : display(nullptr), window(0), context(nullptr) {}
    
    bool initialize(int argc, char** argv) {
        // Open X display
        display = XOpenDisplay(nullptr);
        if (!display) return false;
        
        // Check for window ID (screensaver mode)
        Window parent = DefaultRootWindow(display);
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-window-id") == 0 && i + 1 < argc) {
                parent = strtoul(argv[i + 1], nullptr, 0);
            }
        }
        
        // Get framebuffer config
        static int visualAttribs[] = {
            GLX_X_RENDERABLE    , True,
            GLX_DRAWABLE_TYPE   , GLX_WINDOW_BIT,
            GLX_RENDER_TYPE     , GLX_RGBA_BIT,
            GLX_X_VISUAL_TYPE   , GLX_TRUE_COLOR,
            GLX_RED_SIZE        , 8,
            GLX_GREEN_SIZE      , 8,
            GLX_BLUE_SIZE       , 8,
            GLX_ALPHA_SIZE      , 8,
            GLX_DEPTH_SIZE      , 24,
            GLX_STENCIL_SIZE    , 8,
            None
        };
        
        int fbcount;
        GLXFBConfig* fbc = glXChooseFBConfig(display, DefaultScreen(display), 
                                              visualAttribs, &fbcount);
        
        // Create window
        XVisualInfo* vi = glXGetVisualFromFBConfig(display, fbc[0]);
        Colormap cmap = XCreateColormap(display, parent, vi->visual, AllocNone);
        
        XSetWindowAttributes swa;
        swa.colormap = cmap;
        swa.event_mask = ExposureMask | KeyPressMask;
        
        window = XCreateWindow(display, parent, 0, 0, 1920, 1080, 0,
                              vi->depth, InputOutput, vi->visual,
                              CWColormap | CWEventMask, &swa);
        
        XMapWindow(display, window);
        
        // Create OpenGL context
        context = glXCreateNewContext(display, fbc[0], GLX_RGBA_TYPE, nullptr, True);
        glXMakeCurrent(display, window, context);
        
        // Load OpenGL functions
        gladLoadGL();
        
        // Create shader program
        shaderProgram = createShaderProgram();
        
        // Create fullscreen quad
        createQuad();
        
        XFree(fbc);
        XFree(vi);
        
        return true;
    }
    
    void run() {
        bool running = true;
        XEvent event;
        
        auto startTime = std::chrono::high_resolution_clock::now();
        int frame = 0;
        
        while (running) {
            while (XPending(display)) {
                XNextEvent(display, &event);
                if (event.type == KeyPress) running = false;
            }
            
            // Update uniforms
            auto now = std::chrono::high_resolution_clock::now();
            float time = std::chrono::duration<float>(now - startTime).count();
            
            // Render
            glClear(GL_COLOR_BUFFER_BIT);
            glUseProgram(shaderProgram);
            
            // Set uniforms
            GLint timeLoc = glGetUniformLocation(shaderProgram, "time");
            GLint resLoc = glGetUniformLocation(shaderProgram, "resolution");
            glUniform1f(timeLoc, time);
            glUniform2f(resLoc, 1920.0f, 1080.0f);
            
            glBindVertexArray(vao);
            glDrawArrays(GL_TRIANGLES, 0, 6);
            
            glXSwapBuffers(display, window);
            frame++;
            
            usleep(16000); // ~60fps
        }
    }
    
    void cleanup() {
        glDeleteProgram(shaderProgram);
        glDeleteVertexArrays(1, &vao);
        glDeleteBuffers(1, &vbo);
        glXMakeCurrent(display, None, nullptr);
        glXDestroyContext(display, context);
        XDestroyWindow(display, window);
        XCloseDisplay(display);
    }
};

int main(int argc, char** argv) {
    X11ShaderScreensaver saver;
    if (!saver.initialize(argc, argv)) return 1;
    saver.run();
    saver.cleanup();
    return 0;
}
```

### 6.3 Linux Systemd Integration

```systemd
# /etc/systemd/system/shadercandy.service
[Unit]
Description=ShaderCandy Screensaver
After=graphical.target

[Service]
Type=simple
User=%I
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/%I/.Xauthority
ExecStart=/usr/local/bin/shadercandy-screensaver
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
```

---

## Part 7: Installation Instructions

### 7.1 macOS Installation

#### Prerequisites

- macOS 11.0+ (Big Sur or later)
- Xcode 13.0+ with Metal SDK
- CMake 3.20+

#### Build from Source

```bash
# Clone repository
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy

# Build using Xcode
mkdir build && cd build
cmake .. -G Xcode
xcodebuild -project ShaderCandy.xcodeproj -scheme ShaderCandy -configuration Release

# Or using CMake directly
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)
```

#### Install Screensaver

```bash
# Option 1: Copy to user Library
cp -R build/ShaderCandy.saver ~/Library/Screen\ Savers/

# Option 2: System-wide install (requires sudo)
sudo cp -R build/ShaderCandy.saver /Library/Screen\ Savers/

# Restart System Preferences to see the screensaver
```

#### Automated Install Script

```bash
#!/bin/bash
# install_macos.sh

set -e

echo "Installing ShaderCandy for macOS..."

# Check prerequisites
if ! command -v cmake &> /dev/null; then
    echo "Installing CMake via Homebrew..."
    brew install cmake
fi

# Build
./build.sh

# Install
SAVER_PATH="$HOME/Library/Screen Savers/ShaderCandy.saver"
rm -rf "$SAVER_PATH"
cp -R build/ShaderCandy.saver "$SAVER_PATH"

echo "Installation complete! Open System Preferences > Desktop & Screen Saver"
```

### 7.2 Linux Installation

#### Prerequisites

**Ubuntu/Debian:**

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    libgl1-mesa-dev \
    libglx-dev \
    libx11-dev \
    libxss-dev \
    libxxf86vm-dev \
    xscreensaver \
    xscreensaver-data
```

**Fedora/RHEL:**

```bash
sudo dnf install -y \
    gcc-c++ \
    cmake \
    mesa-libGL-devel \
    libX11-devel \
    libXScrnSaver-devel \
    xscreensaver \
    xscreensaver-base
```

**Arch Linux:**

```bash
sudo pacman -S \
    base-devel \
    cmake \
    mesa \
    libx11 \
    libxss \
    xscreensaver
```

#### Build from Source

```bash
# Clone and build
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Install
sudo make install
```

#### XScreenSaver Integration

```bash
# Add to xscreensaver
mkdir -p ~/.xscreensaver
echo "\n\
shadercandy \t\t\t\t\
    /usr/local/bin/shadercandy-screensaver \\n\\t\
    -root \\n\\t\
    \\n\\t\
    \\n\\t\
    \\n" >> ~/.xscreensaver

# Or create xscreensaver config
cat >> ~/.xscreensaver << 'EOF'
programs:                                    \
    shadercandy                           \
        /usr/local/bin/shadercandy-screensaver\n\
        -root                               \\n\n\
        \\n\n\
        \\n\n\
EOF
```

#### Systemd User Service (Auto-start)

```bash
# Install systemd service
sudo cp install/shadercandy.service /etc/systemd/user/

# Enable for current user
systemctl --user enable shadercandy.service
systemctl --user start shadercandy.service
```

#### Automated Install Script

```bash
#!/bin/bash
# install_linux.sh

set -e

echo "ShaderCandy Linux Installer"
echo "==========================="

# Detect distro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect distribution"
    exit 1
fi

echo "Detected distribution: $DISTRO"

# Install dependencies
case $DISTRO in
    ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y build-essential cmake \
            libgl1-mesa-dev libglx-dev libx11-dev libxss-dev libxxf86vm-dev
        ;;
    fedora|rhel|centos)
        sudo dnf install -y gcc-c++ cmake mesa-libGL-devel \
            libX11-devel libXScrnSaver-devel
        ;;
    arch|manjaro)
        sudo pacman -S --needed base-devel cmake mesa libx11 libxss
        ;;
    *)
        echo "Unsupported distribution. Please install dependencies manually."
        exit 1
        ;;
esac

# Build
echo "Building ShaderCandy..."
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Install
echo "Installing..."
sudo make install

# Setup XScreenSaver
echo "Configuring XScreenSaver integration..."
if [ -f ~/.xscreensaver ]; then
    if ! grep -q "shadercandy" ~/.xscreensaver; then
        echo "Adding to ~/.xscreensaver..."
        sed -i '/^programs:/a\  shadercandy\\\n\\t/usr/local/bin/shadercandy-screensaver\\\n\\t-root\\\n\\t\\\n\\t\\\n\\t\\\n\\t\\\n' ~/.xscreensaver
    fi
else
    echo "Creating ~/.xscreensaver..."
    cat > ~/.xscreensaver << 'EOF'
timeout:        0
cycle:          0
lock:           False
lockTimeout:    0
fade:           True
fadeSeconds:    0.3
mode:           one
selected:       0
programs:                       \
    shadercandy               \\n\\t/usr/local/bin/shadercandy-screensaver\\n\\t-root\\n\\t\\n\\t\\n\\t\\n\\t\\n
EOF
fi

echo ""
echo "Installation complete!"
echo "Restart XScreenSaver or run: xscreensaver-command -restart"
echo "To preview: /usr/local/bin/shadercandy-screensaver"
```

---

## Part 8: Creative Shader Effects Catalog

### 8.1 Effect Categories

1. **Fractal & Mathematical**
   - Mandelbrot/Julia sets
   - 3D fractals (Mandelbulb, Mandelbox)
   - Strange attractors
   - Reaction-diffusion patterns

2. **Particle Systems**
   - GPU-based fluid simulation
   - N-body gravitational systems
   - Nebula/galaxy formation
   - Swarm behaviors

3. **Ray Tracing/Marching**
   - Abstract geometric sculptures
   - Volumetric lighting
   - Subsurface scattering
   - Caustics and reflections

4. **Procedural Generation**
   - Terrain landscapes
   - Organic growth patterns
   - City generation
   - Abstract patterns

5. **Audio-Reactive** (with optional audio input)
   - Waveform visualization
   - Frequency spectrum
   - Beat detection
   - Audio-mapped parameters

### 8.2 Example: Reaction-Diffusion

**Metal Implementation**:

```metal
// Reaction-Diffusion (Gray-Scott model)
kernel void reactionDiffusion(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant float4 &params [[buffer(0)]], // F, K, Du, Dv
    uint2 gid [[thread_position_in_grid]])
{
    float2 texel = 1.0 / float2(input.get_width(), input.get_height());
    float2 uv = float2(gid) * texel;
    
    // Sample current state
    float4 center = input.read(gid);
    float u = center.r;
    float v = center.g;
    
    // Laplacian (9-point stencil)
    float4 laplacian = 
        input.read(gid + uint2(-1,  0)) * 0.2 +
        input.read(gid + uint2( 1,  0)) * 0.2 +
        input.read(gid + uint2( 0, -1)) * 0.2 +
        input.read(gid + uint2( 0,  1)) * 0.2 +
        input.read(gid + uint2(-1, -1)) * 0.05 +
        input.read(gid + uint2(-1,  1)) * 0.05 +
        input.read(gid + uint2( 1, -1)) * 0.05 +
        input.read(gid + uint2( 1,  1)) * 0.05 -
        center;
    
    // Gray-Scott reaction
    float reaction = u * v * v;
    float du = params.z * laplacian.x - reaction + params.x * (1.0 - u);
    float dv = params.w * laplacian.y + reaction - (params.x + params.y) * v;
    
    // Update
    u += du * 1.0;
    v += dv * 1.0;
    
    output.write(float4(u, v, 0.0, 1.0), gid);
}

// Render pass - convert chemical concentration to color
kernel void rdRender(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    float2 state = input.read(gid).rg;
    
    // Color mapping
    float3 color = float3(
        state.x * 0.1 + state.y * 0.9,
        state.x * 0.8 + state.y * 0.2,
        state.x * 0.9 + state.y * 0.1
    );
    
    output.write(float4(color, 1.0), gid);
}
```

---

## Part 9: Performance Monitoring & Profiling

### 9.1 Metal Performance Tools

**Xcode GPU Frame Capture**:

```metal
// Add debug markers
renderEncoder.pushDebugGroup("Post-Processing");
renderEncoder.pushDebugGroup("Bloom Pass 1");
// ... bloom code
renderEncoder.popDebugGroup();
renderEncoder.popDebugGroup();
```

**Metal System Trace**:

```bash
# Command line profiling
xcrun metal-system-trace -o trace.gputrace ./ShaderCandy
```

### 9.2 NVIDIA Nsight

```bash
# Linux profiling with Nsight Graphics
nsys profile -o profile_report ./shadercandy-screensaver
nsys-ui profile_report.nsys-rep
```

### 9.3 Built-in Metrics

```cpp
// FPS counter with moving average
class PerformanceMonitor {
private:
    std::deque<float> frameTimes;
    std::chrono::high_resolution_clock::time_point lastFrame;
    
public:
    void beginFrame() {
        lastFrame = std::chrono::high_resolution_clock::now();
    }
    
    void endFrame() {
        auto now = std::chrono::high_resolution_clock::now();
        float ms = std::chrono::duration<float, std::milli>(now - lastFrame).count();
        
        frameTimes.push_back(ms);
        if (frameTimes.size() > 60) frameTimes.pop_front();
    }
    
    float getAverageFPS() const {
        if (frameTimes.empty()) return 0.0f;
        float avgMs = std::accumulate(frameTimes.begin(), frameTimes.end(), 0.0f) 
                      / frameTimes.size();
        return 1000.0f / avgMs;
    }
};
```

---

## Part 10: Testing Framework

### 10.1 Shader Compilation Tests

```bash
#!/bin/bash
# test_shaders.sh

FAILED=0

# Test Metal shaders
echo "Testing Metal shaders..."
for shader in shaders/metal/*.metal; do
    if xcrun -sdk macosx metal -c "$shader" -o /dev/null 2>&1; then
        echo "✓ $(basename $shader)"
    else
        echo "✗ $(basename $shader)"
        FAILED=$((FAILED + 1))
    fi
done

# Test GLSL shaders
echo "Testing GLSL shaders..."
for shader in shaders/glsl/*.frag; do
    if glslangValidator -V "$shader" -o /dev/null 2>&1; then
        echo "✓ $(basename $shader)"
    else
        echo "✗ $(basename $shader)"
        FAILED=$((FAILED + 1))
    fi
done

exit $FAILED
```

### 10.2 Performance Regression Tests

```python
#!/usr/bin/env python3
# tests/performance_test.py

import subprocess
import json
import time

def run_performance_test(shader_name, duration=10):
    """Run shader for N seconds and collect FPS data"""
    proc = subprocess.Popen(
        ['./build/shadercandy-test', '--shader', shader_name, '--duration', str(duration)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    stdout, _ = proc.communicate()
    results = json.loads(stdout)
    
    return {
        'shader': shader_name,
        'avg_fps': results['avg_fps'],
        'min_fps': results['min_fps'],
        'percentile_99': results['p99_frame_time'],
        'gpu_utilization': results['gpu_percent']
    }

def main():
    shaders = ['fractal', 'particles', 'raymarch', 'noise']
    results = []
    
    for shader in shaders:
        print(f"Testing {shader}...")
        results.append(run_performance_test(shader))
    
    # Compare against baseline
    with open('tests/baseline_performance.json') as f:
        baseline = json.load(f)
    
    for result in results:
        base = next(b for b in baseline if b['shader'] == result['shader'])
        
        fps_drop = (base['avg_fps'] - result['avg_fps']) / base['avg_fps']
        if fps_drop > 0.1:  # 10% regression
            print(f"WARNING: {result['shader']} FPS dropped by {fps_drop*100:.1f}%")

if __name__ == '__main__':
    main()
```

---

## Part 11: CI/CD Pipeline

### 11.1 GitHub Actions Workflow

```yaml
# .github/workflows/build.yml
name: Build and Test

on: [push, pull_request]

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: brew install cmake ninja
      
      - name: Build
        run: |
          mkdir build && cd build
          cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release
          ninja
      
      - name: Test shaders
        run: ./test_shaders.sh
      
      - name: Create screensaver bundle
        run: |
          cd build
          ninja bundle
          
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: ShaderCandy-macOS
          path: build/ShaderCandy.saver

  build-linux:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        compiler: [gcc, clang]
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential cmake \
            libgl1-mesa-dev libx11-dev libxss-dev
          
      - name: Build with ${{ matrix.compiler }}
        run: |
          mkdir build && cd build
          cmake .. -DCMAKE_C_COMPILER=${{ matrix.compiler }} \
                   -DCMAKE_CXX_COMPILER=${{ matrix.compiler }}++
          make -j$(nproc)
      
      - name: Test
        run: ./build/tests/unit_tests

  release:
    needs: [build-macos, build-linux]
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v3
        
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            ShaderCandy-macOS/ShaderCandy.saver
            ShaderCandy-Linux/shadercandy-linux.tar.gz
```

---

## Part 12: Documentation & Community

### 12.1 API Documentation

Generate documentation using Doxygen:

```bash
# Doxyfile configuration
PROJECT_NAME = "ShaderCandy"
INPUT = src/ shaders/
FILE_PATTERNS = *.cpp *.h *.metal *.glsl
GENERATE_HTML = YES
GENERATE_LATEX = NO
```

### 12.2 Shader Development Guide

```markdown
# Shader Development Guide

## Creating a New Shader

1. Create shader files in `shaders/effects/your_shader.{metal,glsl}`
2. Implement the `effect_main` function
3. Add to shader manifest: `shaders/manifest.json`
4. Test with: `./build/shadercandy --shader your_shader`

## Shader Template

```metal
#include "../base/base.metal"

float4 effect_main(float2 centered, vec2 uv, 
                   constant Uniforms &uniforms,
                   texture2d<float> prevFrame,
                   sampler frameSampler) {
    // Your effect here
    float3 color = float3(0.0);
    
    // Example: Gradient
    color = float3(uv, sin(uniforms.time));
    
    return float4(color, 1.0);
}
```

```

### 12.3 Community Contributions

- Shader gallery with user submissions
- Monthly shader competitions
- Tutorial videos
- Discord community

---

## Part 13: Advanced Features

### 13.1 Multi-GPU Support

```cpp
// Enumerate and select GPUs
void enumerateGPUs() {
#if defined(__APPLE__)
    NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();
    for (id<MTLDevice> device in devices) {
        NSLog(@"GPU: %@", device.name);
        NSLog(@"  Low Power: %d", device.isLowPower);
        NSLog(@"  Headless: %d", device.isHeadless);
        NSLog(@"  Memory: %llu MB", device.recommendedMaxWorkingSetSize / (1024*1024));
    }
#else
    // Vulkan physical device enumeration
#endif
}
```

### 13.2 VR/Headless Rendering

```cpp
// Offscreen rendering for headless servers
void renderOffscreen(int width, int height) {
    // Create texture-backed framebuffer
    // Render shader
    // Readback to CPU for video encoding
}
```

### 13.3 Networking (Synchronized Multi-Display)

```cpp
// Synchronize time across displays
void synchronizeTime() {
    // NTP-based time sync
    // Or network time protocol for multi-display installations
}
```

---

## Part 14: Security & Sandboxing

### 14.1 macOS Sandboxing

```xml
<!-- ShaderCandy.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

### 14.2 Shader Safety

```cpp
// Validate shaders before compilation
bool validateShader(const std::string& source) {
    // Check for:
    // - Infinite loops
    // - Excessive texture sampling
    // - Unauthorized system calls
    // - Resource exhaustion patterns
    return true;
}
```

---

## Part 15: Future Roadmap

### Phase 1: Foundation (Months 1-2)

- [ ] Basic framework for Metal and OpenGL
- [ ] 5 base shader effects
- [ ] macOS screensaver bundle
- [ ] Linux X11 screensaver

### Phase 2: Optimization (Months 3-4)

- [ ] SIMD optimizations (NEON, AVX2)
- [ ] GPU profiling integration
- [ ] Performance regression testing
- [ ] 10 additional shader effects

### Phase 3: Polish (Months 5-6)

- [ ] Vulkan backend
- [ ] User shader gallery
- [ ] Audio-reactive shaders
- [ ] Comprehensive documentation

### Phase 4: Advanced (Months 7-9)

- [ ] Machine learning-based effects
- [ ] Multi-GPU support
- [ ] VR integration
- [ ] Mobile ports (iOS/Android)

### Phase 5: Community (Months 10-12)

- [ ] Shader marketplace
- [ ] Cloud rendering
- [ ] Live shader competitions
- [ ] Educational content

---

## Appendix A: Quick Reference

### Shader Uniforms

| Name | Type | Description |
|------|------|-------------|
| `time` | float | Seconds since screensaver started |
| `resolution` | vec2 | Screen resolution in pixels |
| `mouse` | vec2 | Mouse position (0-1) |
| `date` | vec4 | year, month, day, seconds |
| `frame` | int | Frame counter |

### Build Commands

```bash
# macOS
mkdir build && cd build
cmake .. -G Xcode
xcodebuild -scheme ShaderCandy

# Linux
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

### Shader Development

```bash
# Live reload during development
./build/shadercandy --shader myshader --live-reload --fps

# Benchmark
./build/shadercandy --shader myshader --benchmark 60
```

---

*This document is a living specification. Updates and improvements welcome via pull requests.*
