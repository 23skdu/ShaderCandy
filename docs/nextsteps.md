# ShaderCandy: Next Steps & Master Roadmap

**Last Updated:** April 13, 2026

ShaderCandy is a high-performance, cross-platform shader engine and screensaver ecosystem. It has transitioned from a technical foundation to a feature-rich application suite, achieving visual parity with 98+ Metal shaders and 27+ GLSL shaders across macOS and Linux.

---

## 🏗️ Core Architecture

### Cross-Platform Design

**Unified C++ Abstraction Layer**: Platform-independent logic resides in `src/core/`, managing Uniform Buffers, Performance Monitoring, and Shader Registry.

- **macOS Backend**: Metal-native implementation with `ScreenSaverView` integration.
- **Linux Backend**: OpenGL/X11 implementation with `XScreenSaver` integration.

### Shader Framework & Abstraction

**Shared Utilities**: Identical math and SDF libraries for both platforms.

- `shaders/base/utils.metal`: 300+ lines of Metal utilities (Noise, FBM, SDFs, Raymarching).
- `shaders/base/common.glsl`: Equivalent functionality for OpenGL.

### SIMD Optimization

**Runtime CPU Dispatch**: Automatic detection of ARM NEON (Apple Silicon) or AVX2 (x86_64) to maximize performance while maintaining a scalar fallback for older hardware.

---

## 📊 Feature Status Matrix

| Feature | macOS (Metal) | Linux (OpenGL) | Status |
| :--- | :---: | :---: | :--- |
| **Core Rendering** | ✅ | ✅ | Production Ready |
| **Shader Library (98+ Shaders)** | ✅ | ✅ | Production Ready (3D Overhaul Complete) |
| **Hot-Reloading** | ✅ | ✅ | Production Ready |
| **Screensaver Integration** | ✅ | ✅ | Production Ready (Wayland & X11) |
| **Standalone Player** | ✅ | ✅ | Production Ready (multi-display aware) |
| **Wallpaper Mode** | ✅ | ✅ | Production Ready |
| **Audio Reactivity** | ✅ | ✅ | Production Ready (waveform visualized) |
| **JSON Configuration** | ✅ | ✅ | Production Ready (dynamic presets) |
| **Screenshot Capture** | ✅ | ✅ | Production Ready (hotkey enabled) |
| **HDR (10-bit/EDR)** | ✅ | ❌ | macOS-Only |
| **Neural Effects (CoreML)** | ✅ | ❌ | macOS-Only |
| **Ray-Traced Audio** | ✅ | ❌ | macOS-Only |

---

## ✅ Completed Work

| Task | Date |
|------|------|
| 29 shader stubs → working GLSL | 2026-04-09 |
| GLRenderer particle system | 2026-04-09 |
| Wayland keyboard handlers | 2026-04-09 |
| Audio waveform visualization | 2026-04-09 |
| Screenshot capture hotkey | 2026-04-09 |
| OSD notification system | 2026-04-09 |
| Smooth shader transitions | 2026-04-09 |
| Dynamic Shader Configuration | 2026-04-09 |
| Preset Save/Load System | 2026-04-09 |
| Multi-Display Support | 2026-04-09 |
| Shader Hot-Reload with File Watching | 2026-04-09 |
| Audio Input Device Selection UI | 2026-04-09 |
| Frame Rate Cap Option | 2026-04-09 |
| Linux Wayland Integration | — |
| Particle System (compute shaders) | — |
| Linux OpenGL Backend + HDR tone mapping (ACES, Reinhard, Filmic, Hable) | — |
| JSON Configuration (serialization/deserialization + persistence) | — |
| CI/CD Integration (test validation + doc checks) | — |
| 3D Shader Overhaul (`frog`, `owl`, `thieves`, `fallout` as raymarched scenes) | — |
| Shared Utility Consolidation (`lookAt`, `stepped_noise`, SDF primitives) | — |
| Shader Compilation Fix (nil checks → prevent EXC_BAD_ACCESS) | — |
| **Pink/blank screen fix** (debug red layer, bloom default off, HDR SDR path, device nil, NSLog spam) | 2026-04-13 |

---

## 🗺️ Roadmap

### High Priority

- [ ] **Universal Preset API**: Cloud-based backend for community preset sharing, discovery, and rating
- [ ] **HDR Calibration UI**: Integration of SMPTE/Color bar calibration patterns into the preferences window
- [ ] **XCTest Stabilization**: Fully resolve Objective-C ARC warnings and ensure test suite integration in CI/CD

### Platform Parity

- [ ] **GLSL HDR Engine**: Port ACES and Reinhard tone mapping logic to the Linux OpenGL pipeline
- [ ] **Vulkan Backend**: Research and implement a Vulkan renderer for Linux to support modern HDR features (`VK_KHR_swapchain`, `VK_EXT_swapchain_colorspace`)

### Advanced Features

- [ ] **Custom Neural Training**: Allow users to import their own `.mlmodel` files for customized neural style transfers with validation
- [ ] **Granular Controls UI**: Extend the configuration UI to allow per-shader settings (speed, intensity, bloom threshold, color palette) with dynamic controls

### Distribution

- [ ] **Linux Store Packaging**: Finalize Flatpak and Snap package configurations
- [ ] **App Store Finalization**: Final audit of sandboxing and entitlement requirements for the macOS App Store

### Performance & Quality

- [ ] **Performance Benchmark Suite**: Automated testing of all shaders at multiple resolutions with regression detection
- [ ] **Wayland Screensaver Integration**: Complete Wayland implementation and test with sway, GNOME, KDE Plasma

### Documentation

- [ ] **API Documentation**: Add Doxygen configuration for C++ API documentation generation
- [ ] **Architecture Diagrams**: Visual documentation of key systems (Rendering, Audio, Neural)

---

## 🛠️ Development Workflow

### Hot Reload System

Real-time monitoring of the `shaders/` directory. Edits to `.metal` or `.glsl` files trigger immediate recompilation with an automatic fallback to the previous valid state on error.

### Testing & Verification

- **Shader Validation**: Automated compilation of all library shaders via `shadercandy-test`
- **Screenshot Automation**: `shadercandy-screenshot` generates high-resolution previews for visual regression checking
- **C++ Suite**: Math and SIMD unit tests via a custom internal framework

---

## ⌨️ Keyboard Controls

| Key | Action |
|-----|--------|
| Escape / Ctrl+Q | Quit |
| Right Arrow / Space / P | Next shader |
| Left Arrow / N | Previous shader |
| F12 / PrintScreen | Screenshot |
| 1–5 | Adjust shader params |
| Ctrl+S / Ctrl+O | Save/Load preset |
| Tab | Switch display |
| Ctrl++ / Ctrl+- | Intensity |

---

## 📂 Related Documentation

- **[ArchitectureDiagrams.md](./ArchitectureDiagrams.md)**: Visual diagrams of key systems
- **[HdrImplementation.md](./HdrImplementation.md)**: Technical guide for high-bit-depth rendering
- **[NeuralEffectsGuide.md](./NeuralEffectsGuide.md)**: CoreML style transfer documentation
- **[LinuxFeatures.md](./LinuxFeatures.md)**: Linux-specific usage and integration
- **[release_notes_0_1_0.md](./release_notes_0_1_0.md)**: Release notes for v0.1.0

---

*Merged from ShaderCandyMasterPlan.md and nextsteps.md. ShaderCandyMasterPlan.md can now be removed.*