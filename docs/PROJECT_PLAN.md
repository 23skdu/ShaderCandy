# ShaderCandy Project Plan (Consolidated)

This document serves as the master source of truth for the ShaderCandy project status, architecture, and future roadmap.

## 🚀 Project Overview

ShaderCandy is a cross-platform (macOS/Linux) screensaver engine delivering high-performance procedural visuals through native GPU APIs (Metal/OpenGL).

---

## 📍 Current Status: Phase 3 (Advanced Interaction & Polish)

### ✅ Completed Milestones

#### Phase 1: Foundation

* **Core Architecture**: Shared C++/Obj-C++ core with platform-specific backends.
* **Shader Framework**: Unified `ShaderInterop.h` and base shaders for Metal/GLSL.
* **Math Library**: SIMD-accelerated math (NEON/AVX2) for CPU-side calculations.
* **Linux Implementation**: Full X11/OpenGL screensaver with hot-reloading.
* **Initial Shader Gallery**: Nebula, Raymarch Sculpture, Mandelbulb, Reaction-Diffusion.

#### Phase 2: Platform & Quality

* **macOS Screen Saver**: Custom `ScreenSaverView` with native Metal integration.
* **Metal Renderer**: Modern pipeline with triple-buffered uniforms and compute support.
* **Quality Assurance**: Comprehensive test suite (Math, SIMD, Compilation) and CI/CD pipeline.
* **Performance Tracking**: Frame-level monitoring and jitter detection.

#### Phase 3: Interaction & Variety (In Progress)

* **Interactive Particle Swarms**: GPU-based compute simulation with 10k+ particles.
* **Gravitational Interaction**: Left-click (Pull) and Right-click (Push) physics.
* **Shader Preset System**: Curated settings (Zen, Cosmic, Chaos, Vortex) with persistence.
* **Global Controls**: Real-time Speed, Intensity, and Gravity sliders in the Configuration UI.
* **Smooth Transitions**: 2-second cross-fade between shaders using alpha blending.
* **Branchless Optimization**: High-performance shader logic (select/step/mix) to reduce warp divergence.
* **Atomic Pipeline Swaps**: Thread-safe shader hot-reloading.

---

## 🛠 Project Architecture

### 📁 Directory Layout

* `shaders/`: Unified shader source (Effect-specific files).
* `shaders/base/`: Core utilities (Noise, SDFs, HSV).
* `src/core/`: Common C++ logic (Uniforms, Performance).
* `src/platform/macos/`: Metal view and Screen Saver bundle logic.
* `src/platform/linux/`: OpenGL and X11 screensaver logic.

### 🔌 Interop Structure (`Uniforms`)

```cpp
struct Uniforms {
    float time;
    float speed;
    vector_float2 resolution;
    vector_float2 mouse;
    float mouseButtons; // Bitmask: 1=Left, 2=Right
    float intensity;
    float gravity;
    float alpha;        // Cross-fade factor
    vector_float4 date;
    int32_t frame;
    float deltaTime;
};
```

---

## 🗺 Roadmap

### Phase 3: Life & Interactivity (Ongoing)

1. **[ ] Audio Reactivity**:
    * Implement `AudioInput.cpp` (AVFoundation/ALSA).
    * Inject frequency bands and beat data into `Uniforms`.
    * Create `audio_spectrum.metal` effect.
2. **[ ] Multi-Monitor Synchronization**:
    * Implement `MultiDisplayManager.cpp`.
    * Coordinate `time` and `frame` across multiple `MTKView` instances.
3. **[ ] Preset Export/Import**: Allow users to share their "Custom" settings as JSON/Plist.

### Phase 4: Expansion & Distribution

1. **[ ] Standalone App Player**: A companion app for windowed previewing.
2. **[ ] Public Shader Gallery**: Web-based preview of community-shared effects.
3. **[ ] Dynamic Wallpaper Mode**: Active desktop background support for macOS.
4. **[ ] Mobile Companion**: Remote control app for switching shaders/presets.

### Phase 5: Advanced Tech

1. **[ ] Neural Effects**: Integrate CoreML for style transfer or AI-generated noise.
2. **[ ] Ray-Traced Audio**: Physics-based acoustic simulation in compute shaders.
3. **[ ] HDR Mastery**: Support for high-dynamic-range displays and 10-bit color.

---

## 📝 Verified Completion List

* [x] Project Directory Hierarchy
* [x] Metal Base Framework
* [x] GLSL Base Framework
* [x] Linux X11 Backend
* [x] macOS ScreenSaverView
* [x] SIMD Math Library
* [x] Hot-Reload Support
* [x] GPU Particle Simulation
* [x] Interactive Mouse Physics
* [x] Configuration Sliders (Speed/Intensity/Gravity)
* [x] Shader Preset Menu
* [x] Smooth Alpha Transitions
* [x] Full Build & Install Scripts
* [x] Automated Test Runner
* [x] Branchless Shader Logic
