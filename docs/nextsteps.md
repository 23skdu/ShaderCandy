# ShaderCandy: Roadmap for Performance & Stability

**Last Updated:** September 1, 2026

---

## P0 Blockers — Next Release

These items are broken, stubbed, or incomplete and must be addressed before the next release.

### 1. CRITICAL: Audio Ray-Tracing Pipeline is Non-Functional

`AcousticSimulator.simulateReflections()` returns immediately at line 153 because `_rayTracePipeline` is never compiled — no `newComputePipelineStateWithFunction:` call exists in `AcousticSimulator.mm`. All downstream spatial audio (`RayAudioEngine`, `SpatialSoundscapeGenerator`) produces silence or zero acoustic energy.

**Fix:** Compile the compute pipeline during `AcousticSimulator` initialization using the `audio_ray_tracing` kernel function from `shaders/audio/audio_ray_tracing.metal`.

### 2. CRITICAL: PSO Disk Cache Read Path is Stubbed

`MetalPipelineCache.mm:142-145` — the disk cache save path works but the read path falls back to recompilation:
```objc
} else if (_diskCache[key]) {
    // Try disk cache - this is complex with Metal
    // For now, fall back to compilation
}
```
The cache is effectively write-only. Micro-stutter on first shader load persists.

**Fix:** Implement PSO serialization/deserialization or use Metal's binary archive API (`MTLBinaryArchive`) for persistent caching.

### 3. Vulkan Backend is a Complete Stub

`src/vulkan/VulkanRenderer.cpp` — `initialize()` sets `initialized_ = true` without creating any Vulkan objects. `render()` is empty. No Vulkan headers are included.

**Fix:** Either implement a minimal Vulkan renderer or explicitly mark the backend as unsupported and remove it from the build to avoid confusion.

### 4. Quantum Field Shader Missing Metal Port

`shaders/effects/quantum_field.frag` exists but there is no corresponding `quantum_field.metal`. Every other effect shader has both `.frag` and `.metal` versions. This shader is GLSL-only and non-functional on macOS.

**Fix:** Port `quantum_field.frag` to Metal or remove it from the shader catalog.

### 5. Clouds Shader Disabled

`shaders/effects/clouds.metal.disabled` — the `.disabled` extension indicates an unresolved issue. This shader is excluded from the build.

**Fix:** Diagnose and fix the issue, or remove the file entirely.

### 6. Keyboard Shortcuts Are Largely Non-Functional

The documented keyboard reference (below) does not match actual implementation:

| Shortcut | macOS Screensaver | macOS Standalone | Linux X11 | Linux Standalone | Linux Wayland |
|---|---|---|---|---|---|
| P / N (next/prev) | No | No | No | No | No |
| Space (next) | No | No | No | Toggles pause | No |
| 1–5 (params) | No | No | Yes | No | No |
| Ctrl+S/O (save/load) | No | No | Yes | No | No |
| Tab (switch display) | No | No | Yes | No | No |
| Ctrl++/- (intensity) | No | No | Yes | No | No |
| D (debug overlay) | Yes | No | No | No | No |
| T (test suite) | Yes | No | No | No | No |

The macOS standalone player has **zero keyboard shortcut handlers** — it relies entirely on toolbar buttons and menus.

**Fix:** Implement consistent keyboard shortcuts across all platforms, or update documentation to reflect platform-specific availability.

### 7. Battery-Aware Rendering is Incomplete

`WallpaperEngine.mm:451-479` pauses playback on battery via `IOPSCopyPowerSourcesInfo`, but does not degrade quality (resolution, shader complexity). The standalone player and screensaver do not respond to battery state at all.

**Fix:** Implement tiered battery-aware rendering: cap FPS, reduce resolution scale, and simplify shaders when on battery across all modes.

### 8. Unified Memory Management Not Audited

`MetalHeapManager.mm` uses `MTLStorageModeShared` but its usage is limited. Many buffers in `MetalRenderer.mm` and `AcousticSimulator.mm` still use `MTLResourceStorageModePrivate`, preventing true zero-copy CPU/GPU access.

**Fix:** Audit all `MTLBuffer` and `MTLTexture` allocations across the renderer and migrate to `MTLStorageModeShared` where appropriate.

---

## Performance Optimization (Future)

1. **Metal Parallel Encoder Integration**
   Use multiple parallel render command encoders for complex scenes with many post-processing passes. This better utilizes multi-core CPUs during frame encoding.

2. **Indirect Command Buffers (ICB)**
   Implement ICB for particle systems to reduce CPU overhead in frame recording and allow the GPU to generate its own draw calls for dynamic systems.

3. **Variable Rate Shading (VRS)**
   Utilize VRS on supported Apple Silicon (M1+) to reduce fragment shader load in less detailed areas of the screen without visible quality loss.

4. **Metal Mesh Shaders**
   Transition particle rendering and complex geometry to Mesh Shaders for M2/M3 GPUs to significantly improve vertex throughput and culling efficiency. Detection exists (`MetalRenderer.mm:94`) but is unused.

5. **Compute-Based Bloom & Effects**
   Replace current fragment-based bloom (`shaders/effects/bloom.metal`) with a more efficient tile-based compute shader implementation, taking advantage of threadgroup memory on Apple GPUs.

6. **Persistent Pipeline State Object (PSO) Disk Cache**
   See P0 Blocker #2 above. In-memory caching works; disk persistence is non-functional.

---

## Stability & Power Management (Future)

1. **Battery & Thermal Aware Rendering**
   See P0 Blocker #7 above. Thermal throttling works (`MetalRenderer.mm:513-553`); battery-aware quality degradation is incomplete.

2. **Unified Memory Management Audit**
   See P0 Blocker #8 above.

3. **Dynamic LoD for Audio Visualization**
   Scale the complexity of FFT processing and visualization based on current GPU load and audio complexity to ensure stable 60+ FPS during intense segments. No implementation exists.

4. **Spatial Audio Ray-Tracing Optimization**
   See P0 Blocker #1 above. Replace custom broken ray-tracer with MPS-based implementation (`MPSRay`, `MPSTriangleIntersector`, `MTLAccelerationStructure`).

---

## Keyboard Controls Reference

| Key | Action |
| --- | --- |
| Escape / Ctrl+Q | Quit |
| Right Arrow / Space / P | Next shader |
| Left Arrow / N | Previous shader |
| F12 / PrintScreen | Screenshot |
| 1–5 | Adjust shader params |
| Ctrl+S / Ctrl+O | Save/Load preset |
| Tab | Switch display |
| Ctrl++ / Ctrl+- | Intensity |
| D | Toggle debug overlay |
| T | Run shader test suite |

> **Note:** Most shortcuts are only implemented on Linux X11. See P0 Blocker #6 for platform coverage gaps.
