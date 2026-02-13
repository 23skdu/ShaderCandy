# ShaderCandy Master Status & Roadmap (Consolidated)

## 📍 Executive Summary (Feb 2026)

ShaderCandy has successfully transitioned from a technical foundation to a feature-rich, cross-platform engine. The core rendering pipeline (Metal/OpenGL) is stable, and we have achieved visual parity with 27+ shaders across macOS and Linux.

**Key Achievements:**

- **Unified Logic**: Shared uniform structure and performance monitoring.
- **Standalone Mastery**: Full-featured macOS companion app with shader browser and preferences.
- **Screensaver Native**: Deep integration with macOS `ScreenSaverView` and Linux `XScreenSaver`.
- **Advanced Tech**: Neural style transfer (CoreML), HDR mastery (10-bit), and Ray-Traced Audio foundations are all implemented and functional.

---

## 📊 Feature Status Matrix

| Feature | macOS (Metal) | Linux (OpenGL) | Status |
| :--- | :---: | :---: | :--- |
| **Core Rendering** | ✅ | ✅ | Production Ready |
| **Shader Parity (42+)** | ✅ | ✅ | Production Ready |
| **Hot-Reloading** | ✅ | ✅ | Production Ready |
| **Screensaver Integration** | ✅ | ✅ | Production Ready |
| **Standalone Player** | ✅ | 🚧 | macOS-Only (Planned for Linux) |
| **Wallpaper Mode** | ✅ | ❌ | macOS-Only |
| **Audio Reactivity** | ✅ | ❌ | Needs ALSA/PipeWire Port |
| **Neural Effects** | ✅ | ❌ | CoreML Dependent |
| **HDR (10-bit/EDR)** | ✅ | ❌ | macOS-Only |
| **Ray-Traced Audio** | ✅ | ❌ | macOS-Only |
| **Multi-Monitor Sync** | ✅ | 🚧 | Basic support on Linux |

---

## � Upcoming Roadmap & High Priorities

### 1. High Priority (Polish & Parity)

- [ ] **Linux Audio Port**: Port `AVFoundation` logic to `FFTW` + `PipeWire/ALSA` for Linux audio reactivity parity.
- [ ] **Universal Preset API**: Cloud-based sharing (Simple AWS/Backend) for community presets.
- [ ] **HDR Calibration UI**: Add visual calibration patterns (SMPTE/Color bars) to the preferences window for HDR/EDR tuning.
- [ ] **Renderer Polish**: Continue refining frame synchronization and GPU memory handling for ultra-high resolution displays. (Ongoing)

### 2. Next-Gen Enhancements

- [ ] **GLSL HDR Implementation**: Port ACES and Reinhard tone mappers to the Linux OpenGL pipeline.
- [ ] **Wayland Support**: Native Wayland backend for modern Linux distributions.
- [ ] **Vulkan Backend**: Research replacing OpenGL with Vulkan for better performance/HDR on Linux.
- [ ] **Neural Effect Custom Training**: Allow users to drop in their own `.mlmodel` for custom styles.

### 3. Native Distribution

- [ ] **Linux Store Packaging**: Flatpak and Snap versions for better reach.
- [ ] **App Store Readiness**: Final sandbox and entitlement audit for the macOS App Store.

---

## ✅ Completed Milestones (Summary)

All foundational phases including **Core Rendering**, **Platform Integration**, **Standalone App**, **Wallpaper Mode**, **Neural Effects (CoreML)**, **HDR Mastering**, and **Ray-Traced Audio** have been verified as completed and production-ready. Specific recent fixes for **macOS Screensaver stability** and **Metal Performance Optimizations** are also verified.

---

## 📂 Documentation Manifest

- **[PROJECT_PLAN.md](./PROJECT_PLAN.md)**: Deep technical breakdown (Historical).
- **[mastershaderplan.md](./mastershaderplan.md)**: Shader-specific development history.
- **[LINUX_PORT_SUMMARY.md](./LINUX_PORT_SUMMARY.md)**: Details on the GLSL porting effort.
- **[HDR_IMPLEMENTATION.md](./HDR_IMPLEMENTATION.md)**: Technical guide for high-bit-depth rendering.
- **[NEURAL_EFFECTS_GUIDE.md](./NEURAL_EFFECTS_GUIDE.md)**: How to use CoreML style transfer.
- **[WALLPAPER_MODE_GUIDE.md](./WALLPAPER_MODE_GUIDE.md)**: Desktop integration instructions.
- **[STANDALONE_APP_GUIDE.md](./STANDALONE_APP_GUIDE.md)**: Manual for the Player app.
