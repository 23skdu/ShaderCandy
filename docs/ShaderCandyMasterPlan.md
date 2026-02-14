# ShaderCandy: Master Plan & Status

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
| **Neural Effects (CoreML)** | ✅ | ❌ | macOS-Only |
| **HDR (10-bit/EDR)** | ✅ | ❌ | macOS-Only |
| **Ray-Traced Audio** | ✅ | ❌ | macOS-Only |
| **Screenshot Capture** | ✅ | ✅ | Production Ready |

---

## ✅ Completed Milestones

- **Phase 1-3**: Core Rendering, Standalone App, Neural Effects, and HDR foundation.
- **Phase 4**: Linux Port (Screensaver, Standalone, Audio).
- **Phase 5**: Advanced assets and documentation.
- **Recent Update (Feb 2026)**:
  - **3D Shader Overhaul**: Completely recreated `frog`, `owl`, `thieves`, and `fallout` as 3D raymarched scenes.
  - **Shared Utility Consolidation**: Centralized `lookAt`, `stepped_noise`, and SDF primitives in `utils.metal`.
  - **Verification**: All 98 shaders verified to compile and render correctly.

---

## 🗺️ Remaining Tasks (To Complete)

### 1. High Priority

- [ ] **Universal Preset API**: Implementation of a cloud-based backend for community preset sharing and discovery.
- [ ] **HDR Calibration UI**: Integration of SMPTE/Color bar calibration patterns into the preferences window.
- [ ] **XCTest Stabilization**: Fully resolve minor Objective-C ARC warnings and ensure test suite integration in CI/CD.

### 2. Platform Parity

- [ ] **GLSL HDR Engine**: Port ACES and Reinhard tone mapping logic to the Linux OpenGL pipeline.
- [ ] **Vulkan Backend**: Research and initial implementation of a Vulkan renderer for Linux to support modern HDR features.

### 3. Advanced Features

- [ ] **Custom Neural Training**: Allow users to import their own `.mlmodel` files for customized neural style transfers.
- [ ] **Granular Controls**: Extend the configuration UI to allow per-shader settings for speed, intensity, and bloom thresholds.

### 4. Distribution

- [ ] **Linux Store Packaging**: Finalize Flatpak and Snap package configurations.
- [ ] **App Store Finalization**: Final audit of sandboxing and entitlement requirements for the macOS App Store.

---

## 🛠️ Development Workflow

### Hot Reload System

Real-time monitoring of the `shaders/` directory. Edits to `.metal` or `.glsl` files trigger immediate recompilation with an automatic fallback to the previous valid state on error.

### Testing & Verification

- **Shader Validation**: Automated compilation of all library shaders via `shadercandy-test`.
- **Screenshot Automation**: `shadercandy-screenshot` generates high-resolution previews for visual regression checking.
- **C++ Suite**: Math and SIMD unit tests via a custom internal framework.

---

## 📂 Documentation Manifest

All architectural and status information is now contained in this document.

- **[ShaderCandyMasterPlan.md](./ShaderCandyMasterPlan.md)**: (This document)
- **[HdrImplementation.md](./HdrImplementation.md)**: Technical guide for high-bit-depth rendering.
- **[NeuralEffectsGuide.md](./NeuralEffectsGuide.md)**: CoreML style transfer documentation.
- **[LinuxFeatures.md](./LinuxFeatures.md)**: Linux-specific usage and integration.

---
*Last Updated: February 14, 2026*
