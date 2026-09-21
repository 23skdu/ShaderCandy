# Changelog

All notable changes to ShaderCandy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Transition system with 10 types (Crossfade, Dissolve, Wipe×4, Zoom×2, Spin×2) and 10 easing functions
- Post-processing pipeline: vignette, chromatic aberration, film grain, CRT scanlines, color tint
- Adaptive quality: dynamic resolution scaling based on FPS targets
- Smart shader rotation: shuffle mode, favorites list, skip list, configurable auto-rotate
- ShaderParams UBO binding: param1-6, colorPalette, effectFlags now uploaded to shaders
- Full audioData[256] FFT spectrum passed through UniformUploader
- Crossfade transitions in all modes (screensaver, player, wayland) with easing
- Keyboard shortcuts: S (shuffle), F (favorite), X (skip), E (cycle easing), Shift+T (cycle transition type)
- inotify-based file watcher with 100ms polling for shader hot-reload
- GLSL include caching with mtime-based invalidation
- Wallpaper multi-shader rotation with `-dir`, `-rotate`, `-shuffle` options
- `shadercandy-bench` GPU shader performance benchmark tool with JSON export
- Thread safety: `std::mutex` guards on GLRenderer shared state
- TSAN + UBSAN CI jobs alongside ASAN
- Man pages for all executables, GettingStarted.md, CHANGELOG.md
- `SHADERCANDY_API_VERSION` define for shader compile-time API checks
- `getShaderMetadata()` API on ConfigurationManager
- CMake install targets for desktop files, icons, man pages
- FBO-based post-processing with tone mapping and bloom pipeline
- HeadlessRenderer video encoding via ffmpeg (PNG/JPG/PPM output)
- Error callback propagation (setErrorCallback)
- CHANGELOG.md
- CMake install targets with desktop files
- Man pages for shadercandy-screensaver(1), shadercandy-player(1)

### Fixed
- `deserializeSettings()` only read 6 of 21 serialized fields; now reads all 20
- Use-after-free in singleton display change callbacks (static + nullptr cleanup)
- `GLRenderer::setActiveShader` now invokes shaderChangedCallback_ (was dead code)
- UniformUploader SIGSEGV on null GL function pointers in headless test mode
- `minFPS` default corrected from 999 to 0

### Changed
- Wayland screensaver now has full feature parity with X11 (transitions, shuffle, easing, favorites, skip)
- PulseAudio preferred over ALSA per CMakeLists.txt (documentation corrected)
- Test count: 111 tests across 10 suites, 0 valgrind errors

## [0.2.0] - 2025-01-01

### Added
- 113+ procedural shaders with dynamic recursive discovery
- Procedural Gray-Scott reaction-diffusion engine
- Native Wayland layer-shell and session-lock protocol support
- Sub-10ms low-latency audio engine (PipeWire/PulseAudio/ALSA)
- Standalone player and wallpaper engine with hotkey controls
- Compute-based bloom (Metal) and motion-adaptive VRS
- Thermal-aware adaptive ray marching with dynamic LoD
- Unified MultiDisplayManager with virtual canvas aggregation
- CTest integration

### Fixed
- GLSL syntax errors, variable shadowing, and conflicting definitions across 51 shaders
- Nil Metal device initialization on macOS
- Hot-path logging overhead

## [0.1.0] - 2024-12-01

### Added
- Advanced particle systems with GPU compute shaders
- Ray-traced audio and reactivity with FFT spectral analysis
- Complete Wayland support with keyboard handlers
- Dynamic control systems with hotkey support
- On-screen display (OSD) for parameter feedback
- 3D pipeline overhaul with centralized SDF primitives
- SIMD optimizations (ARM NEON, AVX2)
- Hot-reload architecture with fallback protection
