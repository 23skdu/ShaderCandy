# ShaderCandy: Master Plan & Architecture

**Last Updated:** September 12, 2026

## 📍 Executive Summary

ShaderCandy is a high-performance, cross-platform procedural graphics engine and screensaver ecosystem. It provides native GPU-accelerated rendering across macOS (Metal) and Linux (OpenGL 3.3+/4.5, X11, and Wayland). The project features a library of 110+ procedural shaders spanning fractals, raymarched volumetric phenomena, audio-reactive spectrums, and particle simulations.

---

## 🏗️ Core Architecture

```mermaid
flowchart TD
    App[Application Layer\nScreensaver / Standalone / Wallpaper] --> PAL[Platform Abstraction Layer]

    subgraph "Platform Backends"
        PAL --> MetalBackend["macOS Backend\n(Metal 3 / ScreenSaverView / AppKit)"]
        PAL --> GLBackend["Linux Backend\n(OpenGL 3.3+ / X11 / Wayland)"]
    end

    subgraph "Shared C++ Core (src/core/)"
        PAL --> SM["ShaderManager\n(Discovery, Preprocessing, Hot-Reload)"]
        PAL --> MDM["MultiDisplayManager\n(Spanning, Coordinate Mapping, Headless)"]
        PAL --> PM["PerformanceMonitor\n(P99 Frame Timings, Microsecond Timers)"]
        PAL --> UB["UniformBuffer\n(Time, Audio, Resolution, Mouse, OSD)"]
        PAL --> CM["ConfigurationManager\n(JSON Preset Serialization & State)"]
    end

    subgraph "Hardware Acceleration"
        MetalBackend --> MPS["Metal Performance Shaders (Audio Ray-Tracing)"]
        MetalBackend --> ANE["Apple Neural Engine (CoreML Style Transfer)"]
        MetalBackend --> VRS["Variable Rate Shading (Dynamic Rate Maps)"]
        GLBackend --> EGL["EGL / Wayland Layer-Shell"]
        GLBackend --> ALSA["ALSA / PipeWire Audio Capture"]
    end
```

### 1. Cross-Platform Engine Design
Platform-independent business logic resides in `src/core/`, governing uniform structures, performance metrics, JSON preset serialization, display canvas spanning, and shader catalog resolution.
- **macOS Backend**: Native Metal implementation integrating with `ScreenSaverView` for screensavers, `NSWindow`/`MTKView` for the standalone player, and `WallpaperEngine` for live desktop backgrounds.
- **Linux Backend**: Modern OpenGL 3.3+ implementation with native X11 windowing, XScreenSaver extension, and Wayland compositor layer-shell integration.

### 2. Shader Framework & Abstraction
Shaders share a common mathematical and algorithmic foundation across platforms:
- `shaders/base/common.metal`: Metal utilities including 2D/3D noise, Simplex noise, Fractal Brownian Motion (FBM), Raymarching primitives, and SDF combinations.
- `shaders/base/common.glsl`: Direct GLSL equivalents, ensuring visual parity across backends.

### 3. SIMD Optimization
Runtime CPU math dispatch automatically leverages ARM NEON on Apple Silicon and AVX2 on x86_64, with portable scalar fallbacks for universal compatibility.

### 4. Note on Vulkan Backend
A Vulkan backend was previously explored for Linux HDR swapchains (`VK_KHR_swapchain`, `VK_EXT_swapchain_colorspace`). However, following architectural evaluation and contributor clarity audits, Vulkan support was retired. OpenGL 3.3+/4.5 paired with native Wayland and X11 provides full performance parity, lower driver overhead, and maximum stability across Linux distributions.

---

## 📊 Feature Status Matrix

| Feature | macOS (Metal) | Linux (OpenGL) | Status |
| :--- | :---: | :---: | :--- |
| **Core Rendering Pipeline** | ✅ | ✅ | Production Ready |
| **Shader Library (110+ Shaders)** | ✅ | ✅ | Production Ready (3D Raymarching & Music Overhaul) |
| **Hot-Reloading System** | ✅ | ✅ | Production Ready (File Watcher + Rollback) |
| **Screensaver Integration** | ✅ | ✅ | Production Ready (macOS, X11, Wayland) |
| **Standalone Player** | ✅ | ✅ | Production Ready (Windowed, Fullscreen, Multi-Display) |
| **Wallpaper Desktop Mode** | ✅ | ✅ | Production Ready (`WallpaperEngine` / `xwinwrap`) |
| **Multi-Display Spanning** | ✅ | ✅ | Production Ready (`MultiDisplayManager`, `HeadlessRenderer`) |
| **Audio Reactivity (FFT)** | ✅ | ✅ | Production Ready (AVFoundation / ALSA + FFTW3) |
| **JSON Configuration & Presets** | ✅ | ✅ | Production Ready (Dynamic Presets & Persistence) |
| **Screenshot Capture & OSD** | ✅ | ✅ | Production Ready (Universal Hotkeys) |
| **Compute-Based Bloom** | ✅ | ❌ | Production Ready on Metal (Apple Silicon Tile Memory) |
| **Variable Rate Shading (VRS)** | ✅ | ❌ | Production Ready on Metal (Dynamic Rate Maps) |
| **Persistent PSO Disk Cache** | ✅ | ❌ | Production Ready on Metal (`MetalPipelineCache`) |
| **HDR (10-bit / EDR)** | ✅ | ⚠️ | Production Ready on macOS; Tone Mapping Fallback on Linux |
| **Neural Effects (CoreML)** | ✅ | ❌ | macOS-Only (Apple Neural Engine / Metal) |
| **Ray-Traced Audio (MPS)** | ✅ | ❌ | macOS-Only (Metal Performance Shaders) |

---

## ✅ Recently Completed Milestones

- **Metal Compute Bloom & Dynamic VRS**: Replaced fragment bloom with a tile-based compute shader dispatch using Apple Silicon threadgroup memory, and bound dynamic `MTLRasterizationRateMap` passes to accelerate complex raymarched fractals.
- **Unified Core ShaderManager**: Implemented `UnifiedShaderManager` in `src/core/ShaderManager.cpp`, featuring recursive directory scanning, `#include` resolution, uniform reflection, and hot reloading.
- **Multi-Display Virtual Canvas & Headless Renderer**: Full implementation of `MultiDisplayManager` in `src/core/MultiDisplayManager.cpp` supporting `Single`, `SpanAll`, `Clone`, and `Independent` spanning modes, coordinate mapping, and headless offscreen rendering.
- **Microsecond Precision & P99 Timings**: Enhanced `PerformanceMonitor` with microsecond-precision rolling histograms and P99 latency tracking.
- **Spatial Audio MPS Optimization**: Transitioned `AcousticSimulator.mm` to hardware-accelerated ray-tracing using Metal Performance Shaders (`MPSRayIntersector`, `MTLAccelerationStructure`).
- **Persistent Pipeline State Object (PSO) Disk Cache**: Serialized pipeline state caching preventing runtime hitches during shader compilation.
- **Battery-Aware Rendering**: Integrated power source monitoring (`IOPSCopyPowerSourcesInfo`) across macOS player and screensaver modes to throttle frame rates and adjust quality on battery.
- **99% Core Test Coverage**: Comprehensive unit and integration test coverage across all core modules, plus automated compilation regression detection (`tests/ShaderRegressionTests.cpp`).

---

## 🗺️ Roadmap & Future Work

Detailed engineering objectives are maintained in **[nextsteps.md](./nextsteps.md)**. Key priorities include:

1. **GPU-Driven Resource Management**: Descriptor heaps and argument buffers to decouple uniform updates from per-frame CPU pipelines.
2. **Adaptive Ray Marching LoD**: Per-frame thermal metrics and GPU-query-driven `MAX_STEPS` step scaling with dynamic resolution scaling (DRS).
3. **Parallel Command Encoding**: Multi-threaded encoder passes and asynchronous compute queues for HDR tonemapping, bloom, and audio FFT.
4. **Mesh Shaders for Fractals**: Hardware-accelerated triangle generation and cluster culling for M2/M3/M4 Apple Silicon GPUs.
5. **Linux Modernization**: Native PipeWire 0.3 SPA protocol audio and automated Wayland protocol bindings via `wayland-scanner`.
6. **Indirect Command Buffers (ICB)**: GPU-driven particle simulation dispatch without CPU timeline synchronization.
7. **Apple Neural Engine (ANE) Style Pipeline**: Dynamic acoustic room geometry coupled to shader depth buffers, and FP16 quantized style transfer models.
8. **Motion-Adaptive VRS Rate Maps**: Peripheral and motion-vector-based rate map generation.

---

## 📂 Documentation Index

| Document | Purpose |
| :--- | :--- |
| **[nextsteps.md](./nextsteps.md)** | Active engineering roadmap and keyboard controls reference |
| **[ArchitectureDiagrams.md](./ArchitectureDiagrams.md)** | Visual diagrams of rendering, display spanning, audio, and core pipelines |
| **[ApplicationModesGuide.md](./ApplicationModesGuide.md)** | User guide for Standalone Player, Wallpaper Mode, and Screensaver on macOS and Linux |
| **[ShaderAuthoringGuide.md](./ShaderAuthoringGuide.md)** | Developer guide for creating and translating shaders across Metal and GLSL |
| **[LinuxFeatures.md](./LinuxFeatures.md)** | Linux platform architecture, Wayland/X11 details, and build instructions |
| **[HdrImplementation.md](./HdrImplementation.md)** | Technical specification for 10-bit color, EDR, and tone mapping operators |
| **[NeuralEffectsGuide.md](./NeuralEffectsGuide.md)** | CoreML style transfer engine, built-in styles, and ANE integration |
| **[shaders.md](./shaders.md)** | Complete catalog of 110+ procedural shaders with features and categories |
| **[release_notes_0_1_0.md](./release_notes_0_1_0.md)** | Release notes for v0.1.0 |
| **[release_notes_0_2_0.md](./release_notes_0_2_0.md)** | Release notes for v0.2.0 |
