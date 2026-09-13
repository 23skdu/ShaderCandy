# ShaderCandy v0.2.0 Release Notes

We are proud to announce the **v0.2.0** release of ShaderCandy! This release represents a massive evolution in performance, platform stability, procedural shader depth, and engineering maturity across macOS and Linux.

---

## 🌟 Major Highlights & New Capabilities

### 1. Expanded Procedural Shader Library (113+ Shaders on Linux & macOS)
- **Dynamic Shader Discovery**: Replaced hardcoded shader lists on Linux with dynamic recursive discovery, instantly expanding available shaders from 33 to **113+ fully working shaders**.
- **Procedural Gray-Scott Reaction-Diffusion Engine**: Completely redesigned `reaction_diffusion.frag` from a static placeholder into a real-time, interactive, multi-harmonic reaction-diffusion simulator featuring audio reactivity and normal-mapped 3D specular relief lighting.
- **100% GLSL OpenGL Shader Compatibility**: Audited and fixed syntax errors, variable shadowing, conflicting `hsv2rgb` definitions, and missing uniforms across 51 shaders. All 114 fragment shaders now compile cleanly under OpenGL.
- **New Creative Shaders**: Added `pastel_unicorns.frag` and revamped classic shaders (e.g. `reggae`, `particles`, `aquatic`, `knights`).

### 2. Linux Ecosystem & Screensaver Hardening
- **Native Screensaver Integration**: Added unified command-line parsing supporting single-dash and double-dash flags (`-root` / `--root`, `-window-id` / `--window-id`), with out-of-the-box support for XScreenSaver, KDE screensaver (`kscreensavers`), and systemd user services.
- **Sub-10ms Low-Latency Audio Engine**: Implemented native Linux PipeWire / PulseAudio / ALSA low-latency audio capture (256-frame buffers) with thread-safe smoothing, beat detection, and real-time FFT spectrum generation.
- **Production Standalone Player & Wallpaper Engine**: Full interactive controls, OSD overlays, playlist cycling, and hotkey support for both desktop windowed playback and background wallpaper rendering.
- **Robust Wayland Layer-Shell Protocol**: Integrated layer-shell and session-lock protocols with unified keyboard input and multi-monitor cycling.

### 3. Next-Gen GPU Architecture (Metal on macOS)
- **Compute-Based Bloom**: Separable dual-pass downsample/upsample blur pipeline implemented in pure Metal compute shaders.
- **Motion-Adaptive Variable Rate Shading (VRS)**: Hardware rate maps driven dynamically by camera velocity vectors.
- **Thermal-Aware Adaptive Ray Marching**: Real-time LoD adjustment in `PerformanceMonitor` dynamically scales raymarching step budgets (128 down to 48 steps) under thermal throttling.
- **Modern Metal Features**: Added indirect command buffers (ICB) for GPU-driven particle dispatch, mesh shader pipeline state (`MTLMeshRenderPipelineState`), argument buffer suballocation, and multi-queue async compute passes.
- **macOS Sonoma & Sequoia Stability**: Resolved nil Metal device initializations, eliminated pink/blank screens, removed hot-path logging overhead, and implemented lazy-load initialization.

### 4. Core Architecture & Multi-Display
- **Unified MultiDisplayManager**: Seamless multi-monitor spanning, virtual canvas aggregation, and per-display viewport calculation.
- **Resilient ShaderManager**: Safe file watching, atomic hot-reloading with fallback protection to previous valid compilation states, and strict directory filtering.
- **Performance & P99 Telemetry**: Precision microsecond frame timing, rolling P99 frame latency calculation, and Dynamic Resolution Scaling (DRS).

---

## 🧪 Testing, Quality & Code Coverage

- **Automated Test Suites**: **62 / 62 tests passed (100% pass rate)**.
- **CTest Integration**: Fully automated via `ctest` with verified working directory configurations.
- **High Test Coverage**: **95.50% overall line coverage** across all tested `src/` modules:
  - `MathUtils.h`: **100.00%**
  - `UniformBuffer.cpp`: **100.00%**
  - `PerformanceMonitor.cpp`: **100.00%**
  - `PresetManager.cpp`: **100.00%**
  - `GLShaderCompiler.cpp`: **100.00%**
  - `MultiDisplayManager.cpp`: **99.54%**
  - `ConfigurationManager.cpp`: **99.78%**
  - `ShaderManager.cpp`: **97.26%**
  - `AudioInput_Linux.cpp`: **91.21%**
  - `GLRenderer.cpp`: **83.46%**
- **Lint & Memory Safety**: 0 whitespace errors, verified bounds safety, zero-copy pixel buffer creation, and leak-free resource lifecycles.

---

*For detailed architectural specifications and installation guides, see [ShaderCandyMasterPlan.md](./ShaderCandyMasterPlan.md), [LinuxFeatures.md](./LinuxFeatures.md), and [ApplicationModesGuide.md](./ApplicationModesGuide.md).*
