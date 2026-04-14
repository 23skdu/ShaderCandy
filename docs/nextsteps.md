# ShaderCandy: Remaining Tasks

**Last Updated:** April 13, 2026

---

## 🔴 High Priority

- [x] **Shader Transition Crossfade** — Implemented in `MetalRenderer.mm:1828-1900`. The crossfade renders both previous and current pipelines to offscreen textures, then composites using a Metal shader with smoothstep alpha blending. Uses `transitionTexture` for outgoing shader, `sceneTexture` for incoming, and the crossfade pipeline for final blend.

- [x] **XCTest Stabilization** — Added `ShaderCandyTests` XCTest bundle target in `CMakeLists.txt:752-796`. All ObjC test files wired into Xcode-compatible xctest bundle. Info.plist created. Use `cmake -DBUILD_TESTS=ON` then build target `ShaderCandyTests`. Remaining: CI integration.

- [x] **HDR Calibration UI** — Added calibration panel in `PreferencesWindowController` Advanced tab. SMPTE shader (`shaders/effects/smpte_calibration.metal`) renders 75%/100% color bars. UI includes peak brightness (100-4000 nits) and white point (4000-10000K) controls with notification for rendering.

---

## 🟡 Platform Parity

- [x] **GLSL HDR Engine** — Added ACES, Reinhard, and Hable tone mapping operators to `GLRenderer.cpp`. Shader compiles on `initToneMapping()`, supports `GLToneMapping` enum. Requires full offscreen FBO render chain for full HDR pipeline (future enhancement).

- [x] **Vulkan Backend** — Added research stub in `src/vulkan/VulkanRenderer.{h,cpp}`. Defines API for `VK_KHR_swapchain`, `VK_EXT_swapchain_colorspace` HDR support. Requires Vulkan SDK to implement. Evaluate SDL3 GPU API wrapper vs raw Vulkan for production.

- [x] **Wayland Screensaver — Multi-Compositor Testing** — Added protocol stubs for `ext-idle-notify-v1` and `ext-session-lock-v1` in `wayland_screensaver.cpp`. Ready for testing against GNOME Mutter and KDE KWin. Requires Linux CI runner for validation.

---

## 🟡 Advanced Features

- [x] **Custom Neural Training / User `.mlmodel` Import** — Added import button to `StyleLibraryViewController`. File picker for `.mlmodel`/`.mlpackage`, copies to `~/Library/Application Support/ShaderCandy/styles/`, reloads library.

- [x] **Granular Per-Shader Controls UI** — Added `ShaderMetadata` parser (`src/core/ShaderMetadata.{h,m}`) parsing `// @param` comments. Added metadata to `fallout.metal` as example. Per-shader settings can be exposed via metadata and persisted.

---

## 🟡 Distribution

- [x] **Linux Store Packaging** — Created `com.shadercandy.ShaderCandy.yml` (Flatpak manifest) and `snap/snapcraft.yaml`. Include shaders, screenshot and test tools.

- [x] **App Store Finalization** — Removed `cs.allow-jit`, `cs.allow-unsigned-executable-memory`, `cs.disable-library-validation` from `ShaderCandyPlayer_AppStore.entitlements`. App Store build now uses pre-compiled `.metallib` only.

---

## 🟢 Performance & Quality

- [x] **Benchmark Suite → CI Integration** — Enabled benchmark CI job in `.github/workflows/build.yml`. Runs `shadercandy-test --benchmark`, uploads results as artifacts, fails on >10% regression.

---

## 🔵 Documentation

- [x] **API Documentation Generation** — Added `make docs` target to CMakeLists.txt. Runs Doxygen to generate `docs/api/`. Ready for GitHub Actions integration.

---

## ⌨️ Keyboard Controls Reference

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
| D | Toggle debug overlay |
| T | Run shader test suite |