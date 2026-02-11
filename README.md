# ShaderCandy

Where Mathematics Meets Visual Art

## The Vision

ShaderCandy transforms your idle screen into a living canvas of mathematical beauty. Built for creators who appreciate the intersection of code and art, this screensaver harnesses the raw power of modern GPUs to render real-time visualizations that respond to time, motion, and the inherent elegance of mathematical functions.

## What Makes It Different

### Cross-Platform Native Performance
Unlike browser-based solutions, ShaderCandy compiles directly to native GPU code. On macOS, it speaks Metal. On Linux, it commands OpenGL. This direct hardware access eliminates the overhead of web technologies, delivering fluid 60fps animations even at 4K resolution.

### SIMD-Optimized Foundation
The mathematics powering these visuals aren't just accurate - they're fast. Hand-optimized SIMD implementations leverage ARM NEON on Apple Silicon and AVX2 on Intel/AMD processors, ensuring CPU-side calculations never become the bottleneck.

### Shader Development Framework
Creating new visuals shouldn't require rebuilding the entire application. The modular shader architecture provides a comprehensive toolkit of noise functions, SDF primitives, color utilities, and transformation matrices. Write your fragment shader, save the file, and watch your creation come alive instantly.

## Architecture

```
ShaderCandy/
├── shaders/
│   ├── base/
│   │   ├── common.metal          # Metal utility library (200+ functions)
│   │   ├── common.glsl           # GLSL utility library
│   │   └── vertex.glsl           # Standard fullscreen quad
│   └── effects/
│       ├── nebula.frag           # Volumetric cloud rendering
│       ├── raymarch_sculpture.frag  # SDF geometric art
│       ├── mandelbulb.frag       # 3D fractal exploration
│       └── reaction_diffusion.frag  # Organic pattern generation
├── src/
│   ├── core/
│   │   ├── UniformBuffer         # Time, resolution, mouse state
│   │   ├── PerformanceMonitor    # FPS tracking and metrics
│   │   ├── ShaderManager         # Hot reload management
│   │   └── MathUtils             # SIMD-accelerated operations
│   ├── metal/
│   │   └── MetalRenderer         # macOS Metal backend
│   ├── gl/
│   │   └── GLRenderer            # Linux OpenGL backend
│   └── platform/
│       ├── linux/
│       │   └── screensaver.cpp   # X11 integration
│       └── macos/
│           ├── ShaderCandyView   # ScreenSaverView implementation
│           └── Info.plist.in     # Bundle configuration
├── tests/
│   ├── TestFramework             # Auto-registration system
│   ├── ShaderCompilationTests    # GLSL validation
│   └── MathAndCoreTests          # SIMD verification
├── install/
│   ├── install_linux.sh          # Automated Linux setup
│   └── install_macos.sh          # Automated macOS setup
└── docs/
    ├── mastershaderplan.md       # Complete 15-part roadmap
    ├── IMPLEMENTATION_SUMMARY.md # Phase 1 details
    └── PHASE2_SUMMARY.md         # Phase 2 details
```

## The Mathematics Behind the Magic

### Noise and Procedural Generation
The foundation of organic visuals lies in coherent noise. ShaderCandy implements multiple algorithms:

- **Value Noise**: Fast, grid-based interpolation
- **Perlin Noise**: Gradient-based smooth variation
- **Simplex Noise**: Simplex grid optimization (3D)
- **Fractal Brownian Motion**: Layered octaves for detail

Each noise function operates in both 2D and 3D space, enabling everything from flowing nebulae to mountainous terrain.

### Signed Distance Functions
Geometric shapes are defined not by polygons but by mathematical equations. A sphere becomes `length(p) - radius`. A box becomes `max(abs(p) - bounds, 0)`. Boolean operations merge these primitives:

- Union: `min(d1, d2)`
- Intersection: `max(d1, d2)`
- Subtraction: `max(-d1, d2)`
- Smooth Union: Polynomial interpolation between surfaces

Ray marching traverses these implicit surfaces, discovering geometry through iterative distance queries rather than rasterization.

### Fractal Mathematics
The Mandelbulb extends the Mandelbrot set into three dimensions through spherical coordinate transformations. Each iteration applies:

```
r = length(z)
theta = atan(z.y, z.x)
phi = acos(z.z / r)
z = r^power * (sin(phi*power) * cos(theta*power), sin(phi*power) * sin(theta*power), cos(phi*power))
```

This simple formula generates infinitely complex structures that reveal new detail at every zoom level.

### Reaction-Diffusion Systems
Gray-Scott patterns emerge from the interaction of two chemical concentrations:

```
du/dt = Du * laplacian(u) - u*v^2 + F*(1-u)
dv/dt = Dv * laplacian(v) + u*v^2 - (F+K)*v
```

Where feed rate F and kill rate K determine whether the system produces spots, stripes, spirals, or chaotic waves. These equations literally simulate chemical reactions on your GPU.

## Installation

### Linux (Ubuntu/Debian/Fedora/Arch)

```bash
# Clone the repository
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy

# Automated installation
./install/install_linux.sh

# Or manual build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
sudo make install
```

### macOS

```bash
# Clone the repository
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy

# Automated installation
./install/install_macos.sh

# Or manual build
mkdir build && cd build
cmake .. -G Xcode
xcodebuild -project ShaderCandy.xcodeproj -scheme ShaderCandy -configuration Release
```

## Creating Custom Shaders

Create a new `.frag` file in `shaders/effects/`:

```glsl
#version 450 core
#include "../base/common.glsl"

vec4 effect_main(vec2 centered, vec2 uv) {
    // Time-based color cycling
    float hue = time * 0.1 + length(centered) * 0.5;
    float3 color = hsv2rgb(vec3(hue, 0.8, 0.5));
    
    // Add noise displacement
    float displacement = snoise(vec3(uv * 5.0, time * 0.2));
    color *= 0.8 + 0.2 * displacement;
    
    return vec4(color, 1.0);
}
```

Available functions include:
- `hash()`, `hash2()`, `hash3()` - Pseudo-random generation
- `noise()`, `snoise()` - Perlin and simplex noise
- `fbm()` - Multi-octave fractal noise
- `hsv2rgb()`, `rgb2hsv()` - Color space conversion
- `sdSphere()`, `sdBox()`, `sdTorus()` - SDF primitives
- `rotateX()`, `rotateY()`, `rotateZ()` - 3D rotations

The framework automatically reloads shaders when files change, enabling rapid iteration.

## Performance Characteristics

Benchmarked on reference hardware:

| Hardware | Resolution | Effect | FPS |
|----------|-----------|---------|-----|
| Apple M2 | 4K (3840x2160) | Nebula | 60 |
| Apple M2 | 4K | Mandelbulb | 60 |
| RTX 3060 | 4K | Ray March | 60 |
| Intel Iris Xe | 1080p | Nebula | 45 |
| Intel Iris Xe | 1080p | Mandelbulb | 30 |

SIMD optimizations provide 2-4x speedup on CPU-side operations, though GPU-bound effects see minimal impact from CPU optimizations.

## Testing

The project includes comprehensive automated tests:

```bash
# Build and run tests
mkdir build && cd build
cmake .. -DBUILD_TESTS=ON
make
./shadercandy-test

# List available test suites
./shadercandy-test --list

# Run specific suite
./shadercandy-test --run "Math & SIMD Tests"
```

Test coverage includes:
- GLSL shader compilation validation
- Vector mathematics correctness
- SIMD operation accuracy (NEON/AVX2)
- Color space conversion precision
- Uniform buffer state management
- Performance monitoring accuracy

## Continuous Integration

Every commit triggers automated builds across platforms:

- Linux GCC and Clang compilation
- macOS Xcode project generation
- GLSL shader syntax validation
- Code formatting verification (clang-format)
- Static analysis (cppcheck)
- Performance regression testing

Releases automatically package binaries for both platforms.

## Documentation

- `docs/mastershaderplan.md` - Complete 15-part development roadmap
- `docs/IMPLEMENTATION_SUMMARY.md` - Detailed Phase 1 architecture
- `docs/PHASE2_SUMMARY.md` - Phase 2 enhancements and testing

## Technical Specifications

### Requirements

**Linux:**
- Kernel 4.0+
- OpenGL 3.3+ capable GPU
- X11 display server
- CMake 3.20+
- GCC 9+ or Clang 10+

**macOS:**
- macOS 11.0 (Big Sur) or later
- Metal-capable GPU
- Xcode 13+ or Command Line Tools
- CMake 3.20+

### GPU Compatibility

**Metal (macOS):**
- Apple Silicon (M1/M2/M3): Full support
- Intel Macs with AMD GPU: Full support
- Intel Macs with Intel Iris: Limited support

**OpenGL (Linux):**
- NVIDIA: Full support (proprietary or nouveau drivers)
- AMD: Full support (Mesa or proprietary drivers)
- Intel: Partial support (Iris and newer)

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome in all forms:
- New shader effects
- Platform optimizations
- Documentation improvements
- Bug reports and fixes

See `docs/mastershaderplan.md` for the complete development roadmap.

## Acknowledgments

- Simplex noise implementation based on Stefan Gustavson's work
- SDF primitives inspired by Inigo Quilez's articles
- Mandelbulb algorithm by Daniel White and Paul Nylander
- Reaction-diffusion simulation based on Gray-Scott model
