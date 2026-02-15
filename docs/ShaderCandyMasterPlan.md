# ShaderCandy: Master Plan & Roadmap

**Last Updated:** February 14, 2026

## 📍 Executive Summary

ShaderCandy is a high-performance, cross-platform shader engine and screensaver ecosystem. It has transitioned from a technical foundation to a feature-rich application suite, achieving visual parity with 98+ Metal shaders and 27+ GLSL shaders across macOS and Linux.

---

## 🏗️ Core Architecture

### 1. Cross-Platform Design

**Unified C++ Abstraction Layer**: Platform-independent logic resides in `src/core/`, managing Uniform Buffers, Performance Monitoring, and Shader Registry.

- **macOS Backend**: Metal-native implementation with `ScreenSaverView` integration.
- **Linux Backend**: OpenGL/X11 implementation with `XScreenSaver` integration.

### 2. Shader Framework & Abstraction

**Shared Utilities**: Identical math and SDF libraries for both platforms.

- `shaders/base/utils.metal`: 300+ lines of Metal utilities (Noise, FBM, SDFs, Raymarching).
- `shaders/base/common.glsl`: Equivalent functionality for OpenGL.

### 3. SIMD Optimization

**Runtime CPU Dispatch**: Automatic detection of ARM NEON (Apple Silicon) or AVX2 (x86_64) to maximize performance while maintaining a scalar fallback for older hardware.

---

## 📊 Feature Status Matrix

| Feature | macOS (Metal) | Linux (OpenGL) | Status |
| :--- | :---: | :---: | :--- |
| **Core Rendering** | ✅ | ✅ | Production Ready |
| **Shader Library (98+ Shaders)** | ✅ | ✅ | Production Ready (3D Overhaul Complete) |
| **Hot-Reloading** | ✅ | ✅ | Production Ready |
| **Screensaver Integration** | ✅ | ✅ | Production Ready |
| **Standalone Player** | ✅ | ✅ | Production Ready |
| **Wallpaper Mode** | ✅ | ✅ | Production Ready |
| **Audio Reactivity** | ✅ | ✅ | Production Ready |
| **JSON Configuration** | ✅ | ✅ | Production Ready |
| **Screenshot Capture** | ✅ | ✅ | Production Ready |
| **HDR (10-bit/EDR)** | ✅ | ❌ | macOS-Only |
| **Neural Effects (CoreML)** | ✅ | ❌ | macOS-Only |
| **Ray-Traced Audio** | ✅ | ❌ | macOS-Only |

---

## ✅ Recently Completed

- **Linux OpenGL Backend**: Full implementation with HDR tone mapping (ACES, Reinhard, Filmic, Hable)
- **JSON Configuration**: Complete serialization/deserialization with file-based persistence
- **CI/CD Integration**: Test result validation and documentation checks
- **3D Shader Overhaul**: Completely recreated `frog`, `owl`, `thieves`, and `fallout` as 3D raymarched scenes
- **Shared Utility Consolidation**: Centralized `lookAt`, `stepped_noise`, and SDF primitives in `utils.metal`
- **Shader Compilation Fix**: Added nil checks for render pipeline state to prevent EXC_BAD_ACCESS crashes

---

## 🗺️ Remaining Tasks (Roadmap)

### High Priority

- [ ] **Universal Preset API**: Cloud-based backend for community preset sharing, discovery, and rating
- [ ] **HDR Calibration UI**: Integration of SMPTE/Color bar calibration patterns into the preferences window
- [ ] **XCTest Stabilization**: Fully resolve Objective-C ARC warnings and ensure test suite integration in CI/CD

### Platform Parity

- [ ] **GLSL HDR Engine**: Port ACES and Reinhard tone mapping logic to the Linux OpenGL pipeline
- [ ] **Vulkan Backend**: Research and implement a Vulkan renderer for Linux to support modern HDR features (VK_KHR_swapchain, VK_EXT_swapchain_colorspace)

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

## 📂 Documentation Manifest

- **[ShaderCandyMasterPlan.md](./ShaderCandyMasterPlan.md)**: (This document) Master plan and roadmap
- **[HdrImplementation.md](./HdrImplementation.md)**: Technical guide for high-bit-depth rendering
- **[NeuralEffectsGuide.md](./NeuralEffectsGuide.md)**: CoreML style transfer documentation
- **[LinuxFeatures.md](./LinuxFeatures.md)**: Linux-specific usage and integration

---

*This document consolidates the previous ShaderCandyMasterPlan.md and nextsteps.md, with completed items removed.*
