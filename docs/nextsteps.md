# ShaderCandy: Roadmap for Performance & Stability

**Last Updated:** September 1, 2026

---

## P0 Blockers — Completed

All P0 blockers have been resolved. See git history for implementation details.

---

## Performance Optimization (Future)

1. **Metal Parallel Encoder Integration** — Use multiple parallel render command encoders for complex scenes with many post-processing passes.

2. **Indirect Command Buffers (ICB)** — Implement ICB for particle systems to reduce CPU overhead in frame recording.

3. **Metal Mesh Shaders** — Transition particle rendering to Mesh Shaders for M2/M3 GPUs.

4. **Dynamic LoD for Audio Visualization** — Scale FFT processing complexity based on GPU load and audio complexity.

---

## Stability & Power Management (Future)

1. **Thermal Throttling Improvements** — Current implementation in `MetalRenderer.mm:513-553` works but could be more granular with per-shader quality levels.

2. **Spatial Audio MPS Optimization** — Acoustic simulator now uses MPS ray-intersector; further tuning of acceleration structure parameters may improve accuracy.

---

## Keyboard Controls Reference

| Key | macOS Screensaver | macOS Standalone | Linux Screensaver | Linux Standalone | Linux Wayland |
|---|---|---|---|---|---|
| Escape / Ctrl+Q | Yes | Yes | Yes | Yes | Yes |
| Right Arrow / Space / P | Yes | Yes | Yes | Yes | Yes |
| Left Arrow / N | Yes | Yes | Yes | Yes | Yes |
| F12 / PrintScreen | Yes | Yes | Yes | Yes | Yes |
| 1–5 (params) | Yes | Yes | Yes | Yes | Yes |
| Ctrl+S / Ctrl+O | Yes | Yes | Yes | Yes | Yes |
| Tab (switch display) | Yes | Yes | Yes | Yes | Yes |
| Ctrl++ / Ctrl+- | Yes | Yes | Yes | Yes | Yes |
| D (debug overlay) | Yes | Yes | Yes | Yes | Yes |
| T (test suite) | Yes | Yes | Yes | Yes | Yes |
