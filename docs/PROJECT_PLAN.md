# ShaderCandy Master Project Plan & Roadmap

## 🚀 Overview

ShaderCandy is a cross-platform (macOS/Linux) screensaver engine delivering high-performance procedural visuals through native GPU APIs (Metal/OpenGL).

---

## 📍 Current Status: Phase 3 (Advanced Interaction & Polish)

### 🔊 Immediate Focus: Audio & Environment

1. **Audio Reactivity Implementation** (Verified):
    - [x] Create `src/audio/AudioInput.mm` (macOS) using `AVFoundation`.
    - [x] Implement FFT logic for frequency analysis.
    - [x] Map audio magnitudes to `Uniforms` and update shaders.

2. **Atmospheric Soundscapes**:
    - [x] Implement `SoundscapeGenerator` using `AVAudioEngine`.
    - [x] Generative ambient sound (Cosmic Drone) synced to visual complexity.

### 🍏 Apple Metal Platform Improvements (High Priority)

1. **Unified Architecture Finalization**:
    - [x] Refactor `ShaderCandyView.mm` to strictly use `MacOSMetalViewAdapter` and `MetalRenderer`.
    - [x] Reduce `ShaderCandyView.mm` to <200 lines of delegation boilerplate.

2. **Memory and Resource Management**:
    - [x] Implement `MetalResourcePool` for dynamic texture sizing and automatic purging.
    - [x] Use `MTLHeap` for dynamic particle buffers to reduce fragmentation.

3. **Performance Monitoring & Profiling**:
    - [x] Integrate `MTLPerformanceReporter` for GPU timing and bandwidth tracking.
    - [x] Implement on-screen debug overlay for FPS/GPU utilization.

4. **Compute & Apple Silicon Optimization**:
    - [x] Optimize threadgroup sizing for Apple Silicon (512-1024 threads).
    - [x] Implement threadgroup shared memory caching for local particle interactions.
    - [x] Use `simd_sum` and branchless logic for high-performance paths.

### 🖥 Multi-Display & Polish

- [x] **Multi-Monitor Synchronization**: Coordinate `time` and `frame` across multiple `MTKView` instances using `MetalSharedState`.
- [x] **Performance Auto-Scaling**: Dynamically adjust particle counts and bloom quality to maintain target FPS.

---

## 🛠 Project Architecture

- `shaders/`: Unified shader source (Effect-specific files).
- `shaders/base/`: Core utilities (Noise, SDFs, HSV).
- `src/core/`: Common C++ logic (Uniforms, Performance).
- `src/metal/`: Native Metal backend (Renderer, Compiler, Cache).
- `src/platform/macos/`: Metal view and Screen Saver bundle logic.
- `src/platform/linux/`: OpenGL and X11 screensaver logic.

### 🔌 Interop Structure (`Uniforms`)

```cpp
struct Uniforms {
    float time;
    float speed;
    vector_float2 resolution;
    vector_float2 mouse;
    float mouseButtons;
    float intensity;
    float gravity;
    float alpha; // Cross-fade factor
    vector_float4 date;
    int32_t frame;
    float deltaTime;
};
```

---

## 🗺 Roadmap

### Phase 4: Expansion & Distribution

- [ ] **Standalone App Player**: A companion app for windowed previewing.
- [ ] **Active Wallpaper Mode**: Support for desktop backgrounds on macOS.
- [ ] **Preset Export/Import**: JSON-based sharing of custom settings.

### Phase 5: Advanced Tech

- [ ] **Neural Effects**: CoreML integration for style transfer.
- [ ] **Ray-Traced Audio**: Physics-based acoustic simulation in compute shaders.
- [ ] **HDR Mastery**: 10-bit color and EDR support.

---

## ✅ Verified Completion List

### Infrastructure & Platform

- [x] **Unified Renderer Architecture**: `MetalRenderer` established as single source of truth for GPU ops.
- [x] **Robust Shader Compilation**: `ShaderCompiler` with pre-compilation support and include resolution.
- [x] **Pipeline State Cache**: `MetalPipelineCache` with disk serialization and in-memory caching.
- [x] **Platform Backends**: Shared C++ core with separate Metal (macOS) and OpenGL (Linux) paths.
- [x] **SIMD Math Library**: NEON/AVX2 accelerated math.

### Features & Interactivity

- [x] **Interactive Particle Swarms**: GPU-based compute simulation (10k+ particles).
- [x] **Mouse Physics**: Pull/Push interaction with particle systems.
- [x] **Configuration UI**: FPS control, Speed, Intensity, and Gravity sliders.
- [x] **Smooth Transitions**: 2-second alpha cross-fade between shaders.
- [x] **Hot-Reload Support**: File-watcher based shader reloading.
- [x] **Automated Testing**: CI/CD pipeline and local test runner.
- [x] **Branchless Optimization**: High-performance shader logic (select/step/mix).
