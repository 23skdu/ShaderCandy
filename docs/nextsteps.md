# ShaderCandy: Roadmap for Performance & Stability

**Last Updated:** September 1, 2026

---

## P0 Blockers — Next Release

### 1. CRITICAL: Standalone Player Keyboard Navigation Incomplete

`StandaloneAppWindowController.mm` handles arrow keys, Space, P/N, D, T, Tab, F12, and Ctrl shortcuts, but the **macOS screensaver** (`MacOSMetalViewAdapter.mm`) only handles D, S, and T. Left/Right arrows, Space, and all Ctrl shortcuts are missing from the screensaver. The Linux X11 screensaver and Wayland screensaver have partial coverage but no Ctrl+Save/Load.

**Fix:** Implement a shared keyboard dispatcher or ensure all platforms handle the documented shortcut set. Prioritize arrow keys and Space for navigation across all modes.

### 2. CRITICAL: PSO Disk Cache Not Implemented

`MetalPipelineCache.mm` has an in-memory cache that works, but the disk cache stores `NSData` blobs that are never deserialized back into `MTLRenderPipelineState`. The read path falls through to recompilation every time. First-load micro-stutter persists.

**Fix:** Implement `MTLBinaryArchive`-based persistent caching (macOS 12+) to serialize compiled pipeline states to disk and restore them on launch without recompilation.

### 3. CRITICAL: Battery-Aware Rendering Only Works in Wallpaper Mode

`WallpaperEngine.mm` degrades quality (FPS→15, resolution→50%) when on battery, but the standalone player and screensaver modes do not respond to battery state at all. On laptops, these modes will drain battery at full GPU load.

**Fix:** Extend battery-aware quality degradation to `StandaloneAppDelegate` and `MacOSMetalViewAdapter`. Use `IOPSCopyPowerSourcesInfo` to detect battery state and reduce rendering quality accordingly.

### 4. CRITICAL: Audio Ray-Tracing Uses Custom Ray-Tracer Instead of MPS

`AcousticSimulator.mm` compiles and runs a custom `traceAudioRays` compute kernel, but this is a basic implementation. Apple's `MPSRayIntersector` and `MTLAccelerationStructure` provide hardware-accelerated ray tracing on Apple Silicon that is significantly faster.

**Fix:** Replace the custom ray-tracer with MPS-based acceleration structure and ray intersector for production-quality spatial audio.

### 5. Vulkan Backend Returns False but Files Remain

`VulkanRenderer.cpp` returns `false` from `initialize()` and the files are excluded from the build, but the source files (`VulkanRenderer.cpp`, `VulkanRenderer.h`) still exist in the repository. This creates confusion for contributors.

**Fix:** Either implement a minimal Vulkan renderer using `VK_KHR_swapchain` and `VK_EXT_swapchain_colorspace` for Linux HDR support, or remove the files entirely and document the decision in README.md.

### 6. Shader Regression Detector Not Integrated into CI

`ShaderRegressionDetector.cpp` is a standalone tool that detects shader compilation time regressions (>20% threshold), but it is not wired into the test suite or CI pipeline. Regressions can ship unnoticed.

**Fix:** Add a `--regression-check` flag to `shadercandy-test` that runs the regression detector as part of the test suite. Fail the test if any shader regresses by more than 20%.

### 7. No Variable Rate Shading (VRS) Support

VRS is available on Apple Silicon M1+ and can reduce fragment shader load in less detailed screen areas without visible quality loss. Detection exists in `MetalRenderer.mm:94` but is unused.

**Fix:** Implement VRS tier selection based on GPU family, and apply coarser shading rates to peripheral regions of the screen.

### 8. Compute-Based Bloom Not Implemented

The current bloom effect (`shaders/effects/bloom.metal`) uses a fragment-based approach that is suboptimal on Apple GPUs. A tile-based compute shader implementation using threadgroup memory would be more efficient.

**Fix:** Replace the fragment-based bloom with a compute shader that processes tiles in shared memory, reducing bandwidth and improving performance on Apple Silicon.

---

## Performance Optimization (Future)

1. **Metal Parallel Encoder Integration** — Use multiple parallel render command encoders for complex scenes with many post-processing passes.

2. **Indirect Command Buffers (ICB)** — Implement ICB for particle systems to reduce CPU overhead in frame recording.

3. **Metal Mesh Shaders** — Transition particle rendering to Mesh Shaders for M2/M3 GPUs.

4. **Dynamic LoD for Audio Visualization** — Scale FFT processing complexity based on GPU load and audio complexity.

5. **Persistent PSO Disk Cache** — See P0 Blocker #2 above.

---

## Stability & Power Management (Future)

1. **Battery-Aware Rendering (All Modes)** — See P0 Blocker #3 above.

2. **Spatial Audio MPS Optimization** — See P0 Blocker #4 above.

3. **Thermal Throttling Improvements** — Current implementation in `MetalRenderer.mm:513-553` works but could be more granular with per-shader quality levels.

---

## Keyboard Controls Reference

| Key | macOS Screensaver | macOS Standalone | Linux X11 | Linux Standalone | Linux Wayland |
|---|---|---|---|---|---|
| Escape / Ctrl+Q | No | Yes | No | No | Yes |
| Right Arrow / Space / P | No | Yes | No | Toggles pause | Yes |
| Left Arrow / N | No | Yes | No | No | Yes |
| F12 / PrintScreen | No | Yes | No | No | Yes |
| 1–5 (params) | No | No | Yes | No | No |
| Ctrl+S / Ctrl+O | No | Yes | Yes | No | No |
| Tab (switch display) | No | Yes | Yes | No | Yes |
| Ctrl++ / Ctrl+- | No | Yes | Yes | No | No |
| D (debug overlay) | Yes | Yes | No | No | No |
| T (test suite) | Yes | Yes | No | No | No |
