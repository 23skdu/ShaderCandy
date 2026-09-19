# ShaderCandy

ShaderCandy is a cross-platform screensaver application that renders real-time procedural graphics using native GPU APIs. It supports macOS (Metal) and Linux (OpenGL/X11/Wayland).

## Key Features

* **Cross-Platform Native Rendering**: Uses Metal on macOS and OpenGL/Wayland/X11 on Linux for direct hardware access.
* **SIMD Optimizations**: Implements SIMD-accelerated math operations for CPU-side calculations (ARM NEON on Apple Silicon, AVX2 on x86_64).
* **Modular Shader Architecture**: Provides a shared library of GLSL and Metal shader functions (noise, SDFs, math utilities) to simplify effect creation.
* **Hot Reloading**: Automatically reloads and recompiles shaders when source files are modified.
* **Audio Reactivity**: Microphones and system audio input feed directly into FFT spectral analysis for ray-traced audio visualization.
* **Neural Effects**: Integrated CoreML neural style transfer engine on macOS.
* **Dynamic Control Systems**: Configurable UI for shader selection, preset save/load, multi-display support, screenshot hotkeys, and OSD notifications.
* **Advanced Particle Systems**: High-performance compute shader integration for generative multi-million particle simulations.
* **Shader Cycling**: Configurable per-shader duration with smooth crossfade transitions between effects.

## Architecture

```
ShaderCandy/
├── shaders/                # Shader source files (111 effects)
│   ├── base/               # Shared utility functions (common.metal, common.glsl)
│   ├── effects/            # Individual visual effects (fragment shaders)
│   └── music/              # Audio-reactive music visualization shaders
├── src/                    # C++/Objective-C++ source code
│   ├── core/               # Platform-independent core logic (Math, Performance, Utils)
│   ├── config/             # Configuration and preset management
│   ├── audio/              # Audio input, FFT, and spatial audio
│   ├── gl/                 # Linux OpenGL backend (renderer, shader compiler)
│   ├── metal/              # macOS Metal backend implementation
│   └── platform/           # OS-specific entry points (ScreenSaverView, X11, Wayland)
├── tests/                  # Unit and integration tests
├── install/                # Automated install scripts (Linux & macOS)
├── docs/                   # Documentation and roadmaps
└── thumbnails/             # Preview images for each shader
```

## Building and Installation

### Prerequisites

* **macOS**: Xcode Command Line Tools, CMake 3.20+
* **Linux**: GCC/Clang, CMake 3.20+, X11 development headers (`libx11-dev`, `libxss-dev`)

### macOS Build

```bash
git clone https://github.com/23skdu/ShaderCandy.git
cd ShaderCandy
./install/install_macos.sh
```

### Linux Build

```bash
git clone https://github.com/23skdu/ShaderCandy.git
cd ShaderCandy
./install/install_linux.sh
```

### Manual Build (CMake)

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `BUILD_TESTS` | ON | Build test suite |
| `BUILD_AUDIO` | ON | Build audio support (ALSA/PulseAudio + FFTW3) |
| `BUILD_SCREENSAVER_LINUX` | ON | Build X11 screensaver |
| `BUILD_SCREENSAVER_WAYLAND` | ON | Build Wayland screensaver |
| `BUILD_STANDALONE_PLAYER` | ON | Build standalone player (requires GLFW) |
| `BUILD_WALLPAPER` | ON | Build wallpaper mode |

## Testing

```bash
# Build with tests enabled
cmake .. -DBUILD_TESTS=ON
make

# Run all tests
./shadercandy-test

# Run specific test suite
./shadercandy-test --run "Math & SIMD Tests"
```

## Keyboard Controls (Screensaver)

| Key | Action |
|-----|--------|
| Right Arrow / Space / P | Next shader |
| Left Arrow / N | Previous shader |
| D | Toggle debug overlay |
| T | Run test suite |
| F12 / PrintScreen | Screenshot |
| 1-4 | Adjust parameters |
| 5 | Cycle color palette |
| Tab | Switch display |
| Ctrl+S | Save preset |
| Ctrl+O | Load preset |
| Ctrl+/- | Adjust intensity |
| ESC / Q / Click | Quit |

## Performance Benchmarks

Rough performance metrics on reference hardware (4K resolution):

| Hardware | Effect | FPS |
| :--- | :--- | :--- |
| Apple M2 | Nebula | 60 |
| Apple M2 | Mandelbulb | 60 |
| RTX 3060 | Ray March | 60 |
| Intel Iris Xe | Nebula | ~45 |

## Shader Gallery

ShaderCandy ships with **111 shaders** across four categories:

* **Fractals**: Mandelbulb, Mandelbrot, Julia Set variants, Burning Ship, Sierpinski
* **Audio-Reactive**: Audio bars, spectrum, wave, ray tracing, circular visualizer
* **Music**: Genre-themed effects (jazz, hip-hop, electronic, classical, etc.)
* **Abstract**: Plasma, kaleidoscope, vortex, reaction-diffusion, fluid dynamics

## Documentation

* `docs/ShaderCandyMasterPlan.md` -- Consolidated project architecture and feature status
* `docs/ArchitectureDiagrams.md` -- Visual architecture diagrams for rendering, audio, and core systems
* `docs/ApplicationModesGuide.md` -- User guide for Standalone Player, Wallpaper Mode, and Screensavers
* `docs/ShaderAuthoringGuide.md` -- Developer guide for creating and translating shaders (Metal & GLSL)
* `docs/LinuxFeatures.md` -- Linux platform architecture, Wayland/X11 details, and build instructions
* `docs/HdrImplementation.md` -- High-bit-depth rendering and tone mapping documentation
* `docs/nextsteps.md` -- Active performance and stability engineering roadmap

## CI/CD

GitHub Actions CI runs on every push and PR:
- Builds on Ubuntu with full dependency matrix
- Runs the full test suite
- Static analysis with clang-tidy and cppcheck
- Memory leak detection with valgrind

## License

This project is released into the public domain under the [Unlicense](LICENSE).
See [LICENSE](LICENSE) for details.
