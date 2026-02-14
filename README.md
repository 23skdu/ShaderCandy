# ShaderCandy

ShaderCandy is a cross-platform screensaver application that renders real-time procedural graphics using native GPU APIs. It supports macOS (Metal) and Linux (OpenGL/X11).

## Key Features

* **Cross-Platform Native Rendering**: Uses Metal on macOS and OpenGL on Linux for direct hardware access.
* **SIMD Optimizations**: Implements SIMD-accelerated math operations for CPU-side calculations (ARM NEON on Apple Silicon, AVX2 on x86_64).
* **Modular Shader Architecture**: Provides a shared library of GLSL and Metal shader functions (noise, SDFs, math utilities) to simplify effect creation.
* **Hot Reloading**: Automatically reloads and recompiles shaders when source files are modified.

## Architecture

The project is structured as follows:

```
ShaderCandy/
├── shaders/                # Shader source files
│   ├── base/               # Shared utility functions (common.metal, common.glsl)
│   └── effects/            # Individual visual effects (fragment shaders)
├── src/                    # C++/Objective-C++ source code
│   ├── core/               # Platform-independent core logic (Math, Performance, Utils)
│   ├── metal/              # macOS Metal backend implementation
│   ├── gl/                 # Linux OpenGL backend implementation
│   └── platform/           # OS-specific entry points (ScreenSaverView, X11)
├── tests/                  # Unit and integration tests
├── install/                # Installation scripts
└── docs/                   # Documentation and roadmaps
```

## Technical Implementation

### Rendering Pipeline

* **macOS**: Implements the `ScreenSaverView` interface. Uses a `MTKView` backed by valid Metal device. Renders a full-screen quad using a custom render pipeline state.
* **Linux**: Creates an X11 window or targets the root window for screensaver mode. Initializes an OpenGL 3.3+ context.

### Mathematics

The application implements several mathematical concepts for procedural generation:

* **Noise Functions**: Value Noise, Perlin Noise, Simplex Noise, and Fractal Brownian Motion (FBM).
* **Signed Distance Functions (SDFs)**: Primitives (Sphere, Box, Torus) and boolean operations (Union, Intersection, Subtraction) for ray marching.
* **Fractals**: 3D fractal rendering including the Mandelbulb.
* **Reaction-Diffusion**: Gray-Scott model simulation.

## Building and Installation

### Prerequisites

* **macOS**: Xcode Command Line Tools, CMake 3.20+
* **Linux**: GCC/Clang, CMake 3.20+, X11 development headers (`libx11-dev`, `libxss-dev`)

### macOS Build

```bash
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy

# Automated build and install
./install/install_macos.sh
```

### Linux Build

```bash
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy

# Automated build and install
./install/install_linux.sh
```

### Manual Build (CMake)

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

## Testing

The project includes a test suite covering math operations, shader compilation, and core functionality.

```bash
# Build with tests enabled
cmake .. -DBUILD_TESTS=ON
make

# Run all tests
./shadercandy-test

# Run specific test suite
./shadercandy-test --run "Math & SIMD Tests"
```

## Performance Benchmarks

Rough performance metrics on reference hardware (4K resolution):

| Hardware | Effect | FPS |
| :--- | :--- | :--- |
| Apple M2 | Nebula | 60 |
| Apple M2 | Mandelbulb | 60 |
| RTX 3060 | Ray March | 60 |
| Intel Iris Xe | Nebula | ~45 |

## Documentation

* `docs/ShaderCandyMasterPlan.md`: Consolidated project architecture and roadmap.
* `docs/LinuxFeatures.md`: Detailed Linux-specific implementation guide.
* `docs/HdrImplementation.md`: High-bit-depth rendering documentation.

## License

MIT License. See [LICENSE](LICENSE) for details.
