# ShaderCandy: Roadmap for Performance & Stability

**Last Updated:** September 6, 2026
---

## New 10-Part Engineering Improvement Plan

Based on deep code analysis and status verification, the following 10-part roadmap outlines the remaining high-impact enhancements for ShaderCandy:

### Part 1: GPU-Driven Resource Management & Descriptor Heaps
* **Status & Findings:** [TODO] Design and implement GPU-driven descriptor heap management to reduce CPU overhead in binding frequent uniform buffers and textures across Metal, OpenGL, and Vulkan backends.
* **Objective:** Decouple descriptor allocation from the per‑frame CPU pipeline, using GPU‑side heaps and async updates to minimize stalls during complex post‑processing pipelines.

### Part 2: Adaptive Ray Marching LoD & Thermal Scaling
* **Status & Findings:** [TODO] Extend the dynamic LoD framework (Part 6) with per‑frame thermal metrics and GPU‑query‑driven step‑count adjustment.
* **Objective:** Integrate `MTLQuery` results to dynamically scale `MAX_STEPS` and ray‑march epsilon, targeting a stable 60 FPS across all Apple Silicon tiers.

### Part 3: Parallel Command Encoding & Multi‑Queue Async Compute
* **Status & Findings:** [TODO] Build on the single‑queue encoder model by introducing a second async compute queue for HDR tonemapping, bloom, and particle updates.
* **Objective:** Utilize `MTLParallelRenderCommandEncoder` and `MTLSharedEvent` to record split render passes concurrently, reducing encoder bottlenecks.

### Part 4: Mesh Shaders for High‑Geometry Fractals
* **Status & Findings:** [TODO] Implement `MTLMeshRenderPipelineState` for 3D fractal meshes on Apple 3+ GPUs, enabling object‑and‑mesh shaders for culling and detail generation.
* **Objective:** Provide hardware‑accelerated triangle generation and frustum/occlusion culling for complex fractal geometry.

### Part 5: Linux Native PipeWire Audio & Wayland Layer Shell
* **Status & Findings:** [TODO] Replace ALSA/PulseAudio wrappers with native PipeWire 0.3 SPA protocol integration and generate Wayland protocol code via `wayland-scanner`.
* **Objective:** Achieve sub‑millisecond audio reactivity and first‑class screensaver locking on GNOME, KDE Plasma 6, Sway, and Hyprland.

### Part 6: Indirect Command Buffers for Particle Systems
* **Status & Findings:** [TODO] Migrate particle draw command recording from host CPU to `MTLIndirectCommandBuffer`, allowing GPU‑side culling and population of draw arguments.
* **Objective:** Eliminate per‑frame CPU‑to‑GPU synchronization for particle bursts, improving frame‑time consistency.

### Part 7: Dynamic Acoustic Room Geometry & CoreML Neural Engine Pipeline
* **Status & Findings:** [TODO] Generate acoustic obstruction/reflection geometry from scene depth buffers and implement ANE‑accelerated CoreML style transfer with FP16 models and zero‑copy `CVPixelBuffer` pools.
* **Objective:** Real‑time spatial audio coupling and visual stylization at 60 FPS.

### Part 8: Multi‑Display Spanning Coordination Across Platforms
* **Status & Findings:** [TODO] Unify macOS `NSScreen`/CGDisplayList and Linux XRandR/Wayland `wl_output` spanning logic within `MultiDisplayManager`, adding per‑display shader assignment and aspect‑ratio preservation.
* **Objective:** Seamless canvas spanning across heterogeneous multi‑monitor setups on both macOS and Linux.

### Part 9: Unified Cross‑Platform ShaderManager Refresh
* **Status & Findings:** [TODO] Re‑factor `UnifiedShaderManager` to support incremental `#include` resolution, hot‑reload callbacks, and platform‑specific uniform parsing (MSL vs GLSL vs SPIR‑V).
* **Objective:** Provide a single API for preset management, shader hot‑reloading, and cross‑platform file‑system watching.

### Part 10: Dynamic VRS Integration with Motion‑Adaptive Rate Maps
* **Status & Findings:** [TODO] Extend the existing VRS implementation (Part 2) with motion‑dependent peripheral rate adjustments and per‑frame rasterization rate map generation based on scene complexity metrics.
* **Objective:** Further reduce fragment shader workload for raymarched fractals while maintaining visual fidelity through adaptive rate maps.

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