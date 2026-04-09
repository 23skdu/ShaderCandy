# ShaderCandy v0.1.0 Release Notes

We are thrilled to announce the v0.1.0 release of ShaderCandy! This release marks a significant milestone, transforming the project from a technical foundation into a fully featured cross-platform screensaver and procedural graphics engine. 

## 🌟 Key New Features

- **Advanced Particle Systems**: High-performance compute shader integration for generative multi-million particle simulations on the GPU.
- **Ray-Traced Audio & Reactivity**: Microphones and system audio input are now fully supported, feeding directly into FFT spectral analysis for stunning real-time audio visualization and waveform rendering.
- **Complete Wayland Support**: Alongside our existing X11 Linux integration, we have implemented native Wayland surface support and keyboard handlers.
- **Dynamic Control Systems**: We've introduced a robust UI and hotkey system for dynamic shader modification, multi-display target switching, preset save/load, and screenshot captures.
- **On-Screen Display (OSD)**: A brand new overlay UI provides immediate visual feedback for parameter adjustments, shader transitions, and system events.

## 🛠 Architecture & Performance

- **3D Pipeline Overhaul**: Deep refactoring of the raymarching engine with centralized SDF primitives.
- **SIMD Optimizations**: Extensive automatic detection and usage of ARM NEON (Apple Silicon) and AVX2 (x86_64) ensures math routines execute at maximum throughput.
- **Hot-Reload Architecture**: The robust ShaderManager file watcher now guarantees stability, automatically falling back to previously compiled states if an error is detected. 

## 🗺 Roadmap Status

Our updated Master Plan places all core rendering, standalone apps, and screensaver implementations into *Production Ready* status. We are now focusing on Universal Preset API integrations, Vulkan backend support for Linux HDR, and community distribution channels (Flatpak/App Store).

---
*For a complete architectural overview and future steps, see the `docs/ArchitectureDiagrams.md` and `docs/ShaderCandyMasterPlan.md`.*
