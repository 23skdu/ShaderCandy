# ShaderCandy: Remaining Tasks

**Last Updated:** April 13, 2026

---

## 🔴 High Priority

- [ ] **Shader Transition Crossfade** — `transitionToShaderNamed:duration:error:` exists and the state machine is wired, but the actual render-time crossfade (blending previous + next pipeline with `transitionAlpha`) is stubbed out in `renderToDrawable`. Implement proper alpha-blend pass between `previousPipeline` and `currentPipeline` during `_isTransitioning`.

- [ ] **XCTest Stabilization** — No `.xctest` target exists. The ObjC test files (`FalloutShaderTests.mm`, `MetalCompilationTests.mm`, etc.) are in `tests/` but built only via the custom C++ runner. Wire them into an Xcode test target, resolve remaining ARC warnings (`__weak`/`__strong` on `ScreenSaverView` subclass ivar patterns), and integrate into CI.

- [ ] **HDR Calibration UI** — No SMPTE or color-bar calibration UI exists. Add a calibration panel to `PreferencesWindowController` that renders SMPTE 75%/100% color bars via a dedicated Metal shader, alongside peak brightness and white-point controls.

---

## 🟡 Platform Parity

- [ ] **GLSL HDR Engine** — `GLRenderer.cpp` has no tone mapping. Port the ACES and Reinhard operators from `HDRPipeline.mm`/`toneMappingShaderSource` into the GLSL pipeline, using a fullscreen post-process pass after the main render.

- [ ] **Vulkan Backend** — No Vulkan code exists. Research scope: `VK_KHR_swapchain`, `VK_EXT_swapchain_colorspace` for HDR on modern Linux. Evaluate whether to use raw Vulkan or a thin wrapper (e.g. SDL3 GPU API). Implement as a compile-time alternative alongside OpenGL.

- [ ] **Wayland Screensaver — Multi-Compositor Testing** — `wayland_screensaver.cpp` exists (sway/wlroots) but untested against GNOME Mutter and KDE KWin. Validate against `ext-idle-notify-v1` and `ext-session-lock-v1` protocols; add CI job running weston headless.

---

## 🟡 Advanced Features

- [ ] **Custom Neural Training / User `.mlmodel` Import** — `NeuralStyleEngine` and `StyleLibrary` are implemented for bundled models only. Add a file-picker flow in `StyleLibraryViewController` to import user `.mlpackage`/`.mlmodel` files, validate model I/O spec (CHW float32 image in/out), and persist to `~/Library/Application Support/ShaderCandy/styles/`.

- [ ] **Granular Per-Shader Controls UI** — The global speed/intensity/gravity sliders exist. Add a per-shader settings panel (popover from the shader list) with: bloom threshold, color palette picker, animation speed multiplier, custom uniforms exposed via shader metadata comments (`// @param float speed 0.1 3.0`). Persist settings per shader name in the JSON config.

---

## 🟡 Distribution

- [ ] **Linux Store Packaging** — No Flatpak manifest or Snapcraft YAML exists. Create `com.shadercandy.ShaderCandy.yml` (Flatpak) targeting `freedesktop-sdk//23.08` runtime, and `snap/snapcraft.yaml` with `gnome` extension. Include the `shadercandy-screenshot` and `shadercandy-test` tools.

- [ ] **App Store Finalization** — `ShaderCandyPlayer_AppStore.entitlements` currently includes `cs.allow-jit` and `cs.disable-library-validation` which are **rejected** by App Store review for consumer apps. Resolve by: removing runtime GLSL compilation from the App Store build path (use pre-compiled `.metallib` only), removing `cs.disable-library-validation`, and auditing all file-access entitlements for strict sandbox compliance.

---

## 🟢 Performance & Quality

- [ ] **Benchmark Suite → CI Integration** — `ShaderRegressionDetector.cpp` and `PerformanceBenchmarks.cpp` exist and compile, but are not wired into `.github/workflows/build.yml`. Add a CI step running `shadercandy-test –benchmark` on macOS runners, upload results as artifacts, and fail the build on >10% regression in compilation time or frame time.

---

## 🔵 Documentation

- [ ] **API Documentation Generation** — `Doxyfile` is configured but `docs/api/` output is never generated or published. Add a `make doxygen` target to `CMakeLists.txt` and a GitHub Actions step that generates and deploys to GitHub Pages on each release tag.

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