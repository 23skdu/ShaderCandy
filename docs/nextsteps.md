# Next Steps (Active Tasks)

This document tracks the immediate, actionable tasks for ShaderCandy. For the full roadmap and status, see [PROJECT_PLAN.md](./PROJECT_PLAN.md).

## 🔊 Current Focus: Audio & Environment

1. **Audio Reactivity Implementation**:
    * Create `src/audio/AudioInput.mm` (macOS) using `AVFoundation`.
    * Implement FFT logic for frequency analysis.
    * Map audio magnitudes to `Uniforms` and update shaders.
2. **Atmospheric Soundscapes**:
    * Research generative ambient sound synced to visual complexity.

## 🖥 Multi-Display & Polish

1. **Multi-Monitor Synchronization**:
    * Ensure consistent shared state across multiple display views.
    * Handle display arrangement changes gracefully.
2. **Performance Auto-Scaling**:
    * Dynamically adjust particle counts if FPS drops below 55.

## 📦 Distribution

1. **Enhanced Desktop Integration**:
    * Implement "Active Wallpaper" mode.
2. **Standalone Previewer**:
    * Build a small `.app` to preview shaders without opening System Settings.

---
**Last Updated: 2026-02-10**
