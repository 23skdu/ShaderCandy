# ShaderCandy: Roadmap for Performance & Stability

**Last Updated:** September 6, 2026

---

## 10-Part Engineering Improvement Plan

Based on comprehensive deep code analysis of the Metal, OpenGL, Audio, Neural, and Platform subsystems, the following 10-part engineering roadmap defines the high-impact architectural and performance enhancements for ShaderCandy:

### Part 1: Metal Compute Bloom & Post-Processing Pipeline Integration
* **Status & Findings:** `shaders/effects/bloom.metal` implements high-performance compute kernels (`bloom_threshold_compute`, `bloom_blur_h_compute`, `bloom_blur_v_compute`, `bloom_combine_compute`), but `MetalRenderer.mm` currently only dispatches legacy fragment render passes with full-screen quads.
* **Objective:** Wire compute-based bloom directly into `MetalRenderer.mm`, dispatching compute commands using Apple Silicon threadgroup memory tiles (16x16). This eliminates redundant full-screen quad rasterization passes, minimizes memory bandwidth via on-chip tile memory, and reduces frame time during complex post-processing.

### Part 2: Hardware-Accelerated Variable Rate Shading (VRS)
* **Status & Findings:** `MetalRenderer.h` and `MetalRenderer.mm` detect VRS capability (`_supportsVariableRateShading` on Apple Silicon Families) and expose configuration properties (`variableRateShadingEnabled`, `vrsPeripheralRate`), but no `MTLRasterizationRateMap` is allocated or attached to the render pass descriptor.
* **Objective:** Construct and bind a dynamic `MTLRasterizationRateMap` descriptor during render pass creation. Shading rate is downscaled in peripheral screen areas and high-speed motion regions, significantly reducing fragment shader workload for intensive raymarched fractals (`mandelbox`, `mandelbulb_3d`, `raymarch_sculpture`) with no perceptible visual degradation.

### Part 3: Metal Indirect Command Buffers (ICB) for Dynamic Systems
* **Status & Findings:** Particle rendering (`shaders/effects/particles.metal`) and dynamic particle bursts currently rely on host-side CPU recording of draw commands every frame.
* **Objective:** Implement `MTLIndirectCommandBuffer` (ICB) for particle rendering and complex multi-object passes. Allow GPU compute kernels to reset, cull, and populate indirect draw arguments directly on the GPU timeline, reducing CPU-to-GPU synchronization and driver overhead to zero for dynamic systems.

### Part 4: Metal Mesh Shaders for High-Geometry Fractals & Culling
* **Status & Findings:** Capability detection exists for mesh shaders on Apple3+ GPUs (`_supportsMeshShaders = supportsApple3`), but all geometry pipelines currently use traditional vertex fetch and quad strip generation.
* **Objective:** Implement object and mesh shader pipelines (`MTLMeshRenderPipelineState`) for 3D fractal meshes and particle systems on Apple Silicon M2/M3/M4 GPUs. Utilize object shaders for cluster frustum/occlusion culling and mesh shaders for amplified geometric detail and threadgroup-coalesced vertex generation.

### Part 5: Parallel Command Encoding & Multi-Queue Async Compute
* **Status & Findings:** All frame encoding is performed sequentially on a single thread using a single command buffer and queue, leading to encoder bottlenecks when HDR tonemapping, bloom, particles, and debug overlays are simultaneously active.
* **Objective:** Introduce `MTLParallelRenderCommandEncoder` to record split render passes concurrently across multi-core CPU threads. Decouple audio FFT texture updates and offline CoreML style tensor prep onto a dedicated async compute queue with Metal shared events (`MTLSharedEvent`) for synchronization.

### Part 6: Granular Dynamic Level of Detail (LoD) & Thermal Scaling
* **Status & Findings:** Current thermal throttling (`MetalRenderer.mm:520-560`) only steps frame rate down to 30 FPS and disables bloom. Shader internal constants (raymarch step counts, raymarch epsilon) remain static, and audio FFT analysis runs identically at full resolution.
* **Objective:** Implement multi-tiered dynamic LoD across `PerformanceMonitor`, `UniformBuffer`, and shaders:
  1. Dynamically scale raymarch loop bounds (`MAX_STEPS` from 128 down to 48) and increase step epsilon under thermal or frame pacing pressure.
  2. Scale audio FFT analysis bins (from 1024 to 256) adaptively based on CPU load.
  3. Support dynamic resolution scaling (DRS) with bicubic upsampling to guarantee a stable 60 FPS on lower-tier hardware and high-DPI displays.

### Part 7: Unified Cross-Platform Core ShaderManager Architecture
* **Status & Findings:** `src/core/ShaderManager.cpp` is an empty stub returning `nullptr`. Shader discovery, metadata parsing, compilation, and hot-reload polling are duplicated separately across `screensaver.cpp`, `standalone_player.cpp`, `LinuxShaderManager.cpp`, and macOS host adapters.
* **Objective:** Consolidate shader catalog discovery, `#include` preprocessing, uniform reflection, and file-system watching into a centralized cross-platform `ShaderManager`. Eliminate redundant boilerplate across Linux and macOS platform entry points while providing a unified API for preset management and hot reloading.

### Part 8: Multi-Display Spanning & Virtual Display Canvas Implementation
* **Status & Findings:** `src/core/MultiDisplayManager.h` declares full architecture for multi-monitor modes (`Single`, `SpanAll`, `Clone`, `Independent`) and headless offscreen rendering, but lacks implementation files (`.cpp` / `.mm`).
* **Objective:** Implement `MultiDisplayManager.mm` (using `NSScreen` and `CGGetActiveDisplayList` on macOS) and `MultiDisplayManager_Linux.cpp` (using XRandR and `wl_output`). Support synchronized seamless canvas spanning across multi-monitor setups with proper aspect-ratio preservation and per-display shader assignment.

### Part 9: Linux Modernization — Native PipeWire Audio & Wayland Layer Shell
* **Status & Findings:** Linux audio relies on ALSA and PulseAudio compatibility wrappers, lacking native PipeWire SPA protocol integration. Wayland screensaver code required fallback guards in the absence of full wlroots headers.
* **Objective:** Implement native PipeWire audio capture via `libpipewire-0.3` for sub-millisecond audio reactivity. Integrate CMake-driven `wayland-scanner` generation for `ext-idle-notify-v1` and `wlr-layer-shell-unstable-v1` protocols to ensure first-class screensaver locking across modern Wayland compositors (GNOME, KDE Plasma 6, Sway, Hyprland).

### Part 10: Dynamic Acoustic Room Geometry & CoreML Neural Engine Pipeline
* **Status & Findings:** `AcousticSimulator.mm` uses a fixed 12-triangle cube room for spatial audio ray-tracing. `NeuralStyleEngine.mm` provides CoreML style transfer scaffolding but lacks real-time double-buffered pixel transfer pipelines and dynamic scene acoustic coupling.
* **Objective:**
  1. Dynamically generate acoustic obstruction and reflection geometry in `AcousticSimulator.mm` using depth buffers or scene bounding boxes from active shaders.
  2. Optimize CoreML style transfer execution directly on the Apple Neural Engine (ANE) with FP16 quantized models and zero-copy `CVPixelBuffer` pool management to achieve real-time 60 FPS visual stylization.

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
