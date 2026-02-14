# ShaderCandy - Next Steps & Improvement Recommendations

Generated: February 14, 2026

This document outlines 10 strategic priorities for ShaderCandy's continued development based on a comprehensive codebase analysis.

---

## 1. Complete the Linux OpenGL Backend

**Priority: High | Effort: Medium**

**Current State**: The CMakeLists.txt references `src/gl/GLRenderer.cpp` and `GLShaderCompiler.cpp`, but these files do not exist. Only `GLSLWrapper.h` exists in the Linux platform folder.

**Recommendation**:
- Implement a complete OpenGL 3.3+ renderer for Linux matching the Metal API surface
- Port the HDR pipeline tone mapping (ACES, Reinhard) to GLSL
- Add support for the existing 27+ GLSL shaders in the Linux build

**Impact**: Achieves full platform parity for visual effects on Linux.

---

## 2. Implement Configuration Persistence (JSON)

**Priority: High | Effort: Low**

**Current State**: `ConfigurationManager.cpp` line 128 has a TODO: `// TODO: Parse JSON configuration`. Settings are defined but not fully serialized/deserialized.

**Recommendation**:
- Complete the JSON serialization helpers in `ConfigurationManager.h`
- Implement file-based config loading/saving for user preferences
- Add preset export/import functionality with JSON

**Impact**: Users can persist their shader selections, audio settings, and visual preferences across sessions.

---

## 3. Enhance CI/CD Test Integration

**Priority: High | Effort: Low**

**Current State**: The CI pipeline builds and runs `./shadercandy-test` but doesn't check the exit code or verify test results. The `code-quality` job has `continue-on-error: true`.

**Recommendation**:
- Add test result validation to CI (fail build on test failure)
- Fix or suppress cppcheck warnings to remove `continue-on-error`
- Add code coverage reporting
- Integrate shader compilation verification into CI checks

**Impact**: Prevents regressions and ensures code quality standards.

---

## 4. Add Vulkan Renderer for Modern Linux HDR

**Priority: Medium | Effort: High**

**Current State**: HDR is macOS-only. The roadmap mentions Vulkan research but no implementation exists.

**Recommendation**:
- Implement a Vulkan backend as an alternative to OpenGL
- Support VK_KHR_swapchain for present mode
- Enable HDR/10-bit rendering via VK_EXT_swapchain_colorspace
- Target Vulkan 1.3 for maximum compatibility

**Impact**: Provides modern GPU API support on Linux with HDR capabilities.

---

## 5. Implement Custom Neural Model Import

**Priority: Medium | Effort: Medium**

**Current State**: `NeuralStyleEngine` loads bundled models but there's no user-facing way to import custom `.mlmodel` files.

**Recommendation**:
- Add MLModel import via file picker in preferences
- Validate imported models for compatibility (input/output tensor shapes)
- Allow users to browse and select from imported models
- Store custom models in app support directory

**Impact**: Enables user creativity and personalization of neural effects.

---

## 6. Implement Universal Preset API (Cloud Backend)

**Priority: Medium | Effort: High**

**Current State**: Presets are local only. The roadmap mentions "cloud-based backend for community preset sharing."

**Recommendation**:
- Design REST API for preset metadata (shader params, screenshots, ratings)
- Implement preset upload with screenshot preview
- Add search/filter by shader type, rating, author
- Consider simple auth (GitHub OAuth or anonymous)
- Use CDN for preset distribution

**Impact**: Builds community engagement and content library.

---

## 7. Add Granular Per-Shader Controls UI

**Priority: Medium | Effort: Medium**

**Current State**: ConfigurationManager supports shader parameters but the UI doesn't expose them.

**Recommendation**:
- Extend `ShaderControlsViewController` to load parameters from ShaderConfig
- Add dynamic UI controls (sliders, toggles, color pickers) based on ParamType
- Allow per-shader settings for: speed, intensity, bloom threshold, color palette
- Persist per-shader overrides in configuration

**Impact**: Users can fine-tune each shader to their preferences.

---

## 8. Fix Documentation Broken Links & Add API Docs

**Priority: Low | Effort: Low**

**Current State**: The CI job references `docs/mastershaderplan.md` (lowercase) but the file is `ShaderCandyMasterPlan.md`. References `IMPLEMENTATION_SUMMARY.md` which doesn't exist.

**Recommendation**:
- Fix broken documentation references in CI
- Add Doxygen configuration for C++ API documentation
- Generate API docs for public headers (MetalRenderer, ConfigurationManager, etc.)
- Add architecture diagrams for key systems

**Impact**: Improves developer onboarding and documentation quality.

---

## 9. Add Performance Profiling & Benchmark Suite

**Priority: Low | Effort: Medium**

**Current State**: MTLPerformanceReporter collects metrics but there's no comprehensive benchmarking.

**Recommendation**:
- Add automated benchmark suite that tests all shaders at multiple resolutions
- Track GPU time, frame time, memory usage per shader
- Generate performance reports (JSON/HTML)
- Add regression detection in CI (alert if shader FPS drops >10%)
- Document performance characteristics for each hardware tier

**Impact**: Enables data-driven optimization and hardware recommendations.

---

## 10. Add Wayland Screensaver Integration

**Priority: Low | Effort: Medium**

**Current State**: CMakeLists.txt has `BUILD_SCREENSAVER_WAYLAND` option but source files may be incomplete or untested.

**Recommendation**:
- Complete Wayland screensaver implementation
- Test with sway, GNOME, KDE Plasma Wayland sessions
- Add support for KDE Plasma's plasma-workspace screensaver API
- Verify audio works in Wayland session

**Impact**: Full compatibility with modern Linux Wayland-based desktops.

---

## Summary

| # | Recommendation | Priority | Effort | Status |
|---|----------------|----------|--------|--------|
| 1 | Complete Linux OpenGL Backend | High | Medium | ✅ DONE |
| 2 | Implement JSON Configuration | High | Low | ✅ DONE |
| 3 | Enhance CI/CD Test Integration | High | Low | ✅ DONE |
| 4 | Add Vulkan Renderer | Medium | High | Pending |
| 5 | Custom Neural Model Import | Medium | Medium | Pending |
| 6 | Universal Preset API | Medium | High | Pending |
| 7 | Granular Shader Controls UI | Medium | Medium | Pending |
| 8 | Fix Documentation | Low | Low | Pending |
| 9 | Performance Benchmark Suite | Low | Medium | Pending |
| 10 | Wayland Integration | Low | Medium | Pending |

---

## Completed in This Session

### 1. Linux OpenGL Backend (COMPLETED)
- Created `src/gl/GLRenderer.h` - Header matching MetalRenderer interface
- Created `src/gl/GLRenderer.cpp` - Full OpenGL 3.3+ renderer implementation with:
  - Shader compilation and program management
  - Uniform block support
  - Bloom post-processing configuration
  - Audio reactivity support
  - HDR tone mapping (ACES, Reinhard, Filmic, Hable)
  - Hot reload support
  - Performance metrics tracking
- Created `src/gl/GLShaderCompiler.h` - Shader compiler interface
- Created `src/gl/GLShaderCompiler.cpp` - GLSL shader compiler implementation
- Updated CMakeLists.txt to handle macOS OpenGL framework

### 2. JSON Configuration (COMPLETED)
- Implemented complete JSON serialization in ConfigurationManager.cpp:
  - `serializeSettings()` - Full AppSettings serialization
  - `deserializeSettings()` - Settings parsing from JSON
  - `serializeShaderConfig()` - Shader config serialization
  - `deserializeShaderConfig()` - Shader config parsing
  - JSON string escaping and parsing utilities
- Updated `loadFromFile()` to actually parse JSON

### 3. CI/CD Enhancements (COMPLETED)
- Fixed test execution to properly fail on test failures
- Fixed documentation checks:
  - Changed `docs/mastershaderplan.md` → `docs/ShaderCandyMasterPlan.md`
  - Changed `IMPLEMENTATION_SUMMARY.md` → `docs/HdrImplementation.md`
- Removed `continue-on-error` from cppcheck for proper validation

---

*Analysis performed on ShaderCandy commit: February 14, 2026*
*Project version: 1.0.0*
