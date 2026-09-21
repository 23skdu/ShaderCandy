# ShaderCandy: Roadmap for Performance & Stability

**Last Updated:** September 20, 2026
---

## Executive Status

All initial P0 blockers and Phase 1 core improvements have been completed, plus significant Linux GL enhancements:

- **Metal Compute Bloom**: Tile-based compute shader dispatch using Apple Silicon threadgroup memory (`bloom.metal`, `MetalRenderer.mm`).
- **Linux FBO Bloom Pipeline**: Configurable quality levels (Low/Medium/High/Ultra) with Gaussian blur passes and additive composite (`GLRenderer.cpp`).
- **Dynamic Variable Rate Shading (VRS)**: Hardware-accelerated rate map allocation and attachment on Apple Silicon M-series (`MetalRenderer.mm`).
- **Unified Core ShaderManager**: Cross-platform shader discovery, include preprocessing, inotify-based hot reloading, and state tracking (`src/core/ShaderManager.cpp`).
- **Multi-Display Virtual Canvas & Headless Renderer**: Canvas coordinate mapping (`SpanAll`, `Clone`, `Independent`) and offscreen multi-pass rendering with ffmpeg video encoding (`src/core/MultiDisplayManager.cpp`).
- **Performance Monitor P99 Metrics**: Microsecond-precision frame timing, frame-drop counters, and P99 latency tracking (`src/core/PerformanceMonitor.cpp`).
- **Persistent PSO Disk Cache**: Thread-safe pipeline state object caching with disk serialization (`src/metal/MetalPipelineCache.mm`).
- **Battery-Aware Rendering**: Dynamic frame rate throttling and power-state adaptation (`WallpaperEngine.mm`, `StandaloneAppDelegate.mm`).
- **MPS Spatial Audio Optimization**: Hardware-accelerated ray-tracing via Metal Performance Shaders (`AcousticSimulator.mm`).
- **GLRendererTypes.h**: Type extraction for GL-only structs/enums (GLBloomConfig, GLParticleConfig, GLRendererError, etc.).
- **UniformUploader**: Cached uniform location dispatch for GLRenderer (`src/gl/UniformUploader.h`).
- **Shader Include Caching**: `GLSLWrapper` with mtime-based file caching for fast `#include` resolution.
- **Audio Utils**: `packAudioForShader`, `getDominantFrequency`, `getSpectralCentroid`, `bandHasEnergy` (`src/audio/Utils`).
- **Transition System**: 10 transition types + 10 easing functions with `GLTransitionConfig` (`src/gl/GLRendererTypes.h`).
- **Post-Processing Config**: `GLPostProcessConfig` — vignette, chromatic aberration, film grain, CRT scanlines, color tint.
- **Adaptive Quality**: `GLAdaptiveQualityConfig` — dynamic resolution scaling to maintain target FPS.
- **Smart Shader Rotation**: Shuffle, favorites/skip lists, auto-rotate with configurable per-shader duration.
- **UniformUploader Enhancements**: Now uploads ShaderParams (param1-6, colorPalette, effectFlags) and full audioData[256]; null-guard for headless mode.
- **Test Suite**: **109 tests across 10 suites**, 0 valgrind errors, 0 application memory leaks.

---

## Completed Roadmap Items

All 8 engineering initiatives from the original roadmap have been completed:

1. **GPU-Driven Resource Management & Descriptor Heaps** -- GPU-driven argument buffer allocation and descriptor heap suballocation in `MetalHeapManager`.
2. **Adaptive Ray Marching LoD & Thermal Scaling** -- Dynamic thermal-aware raymarching bounds and DRS in `PerformanceMonitor.cpp`.
3. **Parallel Command Encoding & Multi-Queue Async Compute** -- Split render pass encoding and async compute queue synchronization in `MetalRenderer`.
4. **Mesh Shaders for High-Geometry Fractals** -- Mesh shader pipeline (`MTLMeshRenderPipelineState`) for hardware-accelerated fractal rendering.
5. **Linux Native PipeWire Audio & Wayland Layer Shell** -- Sub-10ms PipeWire/PulseAudio/ALSA audio, Wayland layer-shell protocol integration.
6. **Indirect Command Buffers for Particle Systems** -- `MTLIndirectCommandBuffer` for GPU-driven particle dispatch.
7. **Dynamic Acoustic Room Geometry & CoreML Neural Engine Pipeline** -- Dynamic scene depth coupling and FP16 model optimization.
8. **Motion-Adaptive Variable Rate Shading Rate Maps** -- Peripheral and motion-vector-based rate map generation.

---

## Keyboard Controls Reference

| Key | macOS Screensaver | macOS Standalone | Linux Screensaver | Linux Standalone | Linux Wayland |
|---|---|---|---|---|---|
| Escape / Ctrl+Q | Yes | Yes | Yes | Yes | Yes |
| Right Arrow / Space / P | Yes | Yes | Yes | Yes | Yes |
| Left Arrow / N | Yes | Yes | Yes | Yes | Yes |
| F12 / PrintScreen | Yes | Yes | Yes | Yes | Yes |
| 1–5 (params / speed) | Yes | Yes | Yes | Yes | Yes |
| Ctrl+S / Ctrl+O | Yes | Yes | Yes | Yes | Yes |
| Tab (switch display / shader) | Yes | Yes | Yes | Yes | Yes |
| Ctrl++ / Ctrl+- | Yes | Yes | Yes | Yes | Yes |
| D (debug overlay) | Yes | Yes | Yes | Yes | Yes |
| T (test suite) | Yes | Yes | Yes | Yes | Yes |
