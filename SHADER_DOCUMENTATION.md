# ShaderCandy Shader Documentation

## Overview

ShaderCandy includes **27+ shaders** organized into a modular architecture with shared utilities and specialized visual effects. This documentation provides comprehensive information about each shader, their functionality, parameters, and technical implementation.

## Shader Inventory

### Base Utilities
| File | Location | Description |
|------|----------|-------------|
| `common.glsl` | `shaders/base/` | Core utilities including uniforms, hash functions, noise functions (value, simplex, fbm), SDF primitives, color conversions, and math operations |
| `vertex.glsl` | `shaders/base/` | Basic vertex shader for full-screen quad rendering |

### Effects Category (17 shaders)

#### Fractal & Mathematical
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `mandelbrot_set.frag` | `shaders/effects/` | Classic Mandelbrot fractal with deep zoom capabilities | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `julia_set.frag` | `shaders/effects/` | Julia fractal with animated constant and mouse interaction | `time`, `speed`, `intensity`, `alpha`, `mouseButtons` | `common.glsl` |
| `fractal_zoom.frag` | `shaders/effects/` | Animated fractal zoom with color cycling | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `mandelbrot.frag` | `shaders/effects/` | Alternative Mandelbrot implementation with orbit traps | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `mandelbulb.frag` | `shaders/effects/` | 3D Mandelbulb fractal with ray marching | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `mandelbulb_3d.frag` | `shaders/effects/` | Alternative 3D Mandelbulb with different power function | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |

#### Ray Marching & 3D
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `raymarch_sculpture.frag` | `shaders/effects/` | Abstract geometric sculpture with SDF operations | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `nebula.frag` | `shaders/effects/` | Volumetric nebula clouds with ray marching | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `dna_helix.frag` | `shaders/effects/` | DNA double helix molecular visualization | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |

#### Audio Reactive
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `audio_spectrum.frag` | `shaders/effects/` | Music-reactive spectrum with particles and bars | `time`, `speed`, `intensity`, `alpha`, `audioUniforms` | `common.glsl` |

#### Cellular & Pattern
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `voronoi_cells.frag` | `shaders/effects/` | Animated Voronoi cell pattern | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `reaction_diffusion.frag` | `shaders/effects/` | Gray-Scott reaction-diffusion simulation | `time`, `speed`, `intensity`, `alpha`, `rdState` | `common.glsl` |

#### Abstract & Artistic
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `quantum_field.frag` | `shaders/effects/` | Quantum wave function visualization | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `kaleidoscopic_tunnel.frag` | `shaders/effects/` | Kaleidoscopic tunnel with swirling patterns | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `liquid_gradient.frag` | `shaders/effects/` | Smooth liquid-like gradient waves | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `starfield_warp.frag` | `shaders/effects/` | Warp-speed starfield with depth effects | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `bloom.frag` | `shaders/effects/` | Bloom/glow effect with floating orbs | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `neon_pulse.frag` | `shaders/effects/` | Neon ring pulse with color cycling | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |

#### Game & Interactive
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `capman.frag` | `shaders/` | Pacman-inspired game with ghosts and pellets | `time`, `speed`, `intensity`, `alpha`, `gameTime`, `playerPos`, `ghostPos[]` | `common.glsl` |

### Simple Effects (6 shaders)
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `checkerboard.frag` | `shaders/` | Animated checkerboard with shimmer | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `plasma.frag` | `shaders/` | Multi-frequency plasma effect | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `ripples.frag` | `shaders/` | Concentric ripple waves from center | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `spiral.frag` | `shaders/` | Logarithmic spiral with color variation | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `gradient_waves.frag` | `shaders/` | Flowing gradient waves | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |
| `tunnel.frag` | `shaders/` | 3D tunnel with spiral patterns | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |

#### Special Effects
| Shader | Location | Visual Effect | Key Parameters | Dependencies |
|--------|----------|---------------|----------------|--------------|
| `flying_toasters.frag` | `shaders/` | Flying toaster screensaver with ray marching | `time`, `speed`, `intensity`, `alpha` | `common.glsl` |

## Visual Documentation

### Complexity & Performance Analysis

#### High Complexity (Ray Marching & 3D)
- **`raymarch_sculpture.frag`** - 169 lines, 100 ray march iterations, soft shadows, AO, multiple lighting
- **`nebula.frag`** - 150 lines, 64 volume samples, multi-layer noise, star field
- **`dna_helix.frag`** - 198 lines, 100 ray march iterations, complex SDF operations
- **`mandelbulb.frag`** - 235 lines, 128 ray march iterations, adaptive stepping, multiple lights
- **`quantum_field.frag`** - 152 lines, complex wave functions, multiple interference patterns
- **`flying_toasters.frag`** - 171 lines, 64 ray march iterations, domain repetition, multiple toasters

#### Medium Complexity
- **`audio_spectrum.frag`** - 183 lines, particle system, waveform visualization, circular bars
- **`reaction_diffusion.frag`** - 71 lines, 9-point stencil, Gray-Scott model
- **`liquid_gradient.frag`** - 24 lines, multi-frequency sine waves

#### Low Complexity
- **`checkerboard.frag`** - 34 lines, simple pattern generation
- **`plasma.frag`** - 23 lines, basic plasma effect
- **`ripples.frag`** - 30 lines, concentric wave patterns
- **`spiral.frag`** - 30 lines, polar coordinate spiral
- **`gradient_waves.frag`** - 24 lines, flowing gradient waves
- **`tunnel.frag`** - 34 lines, simple tunnel effect

### Visual Characteristics

#### Color Schemes
- **Nebula Effects**: Deep purples, blues, cyans with orange highlights
- **Fractal Effects**: Iridescent, psychedelic color palettes with smooth gradients
- **Quantum Effects**: Scientific color schemes (blues, purples, cyans)
- **Game Effects**: Classic game colors (yellow, red, blue, cyan)
- **Abstract Effects**: Neon/pulse colors with smooth transitions

#### Animation Styles
- **Time-based**: Most shaders use `time * speed` for animation
- **Audio-reactive**: `audio_spectrum.frag` responds to music with volume, bass, mid, treble
- **Mouse-interactive**: `julia_set.frag` allows mouse control of fractal parameters
- **Game-state**: `capman.frag` uses game-specific uniforms for interactive gameplay

#### Pattern Types
- **Geometric**: Checkerboard, spirals, tunnels
- **Organic**: Nebula, liquid gradients, reaction diffusion
- **Mathematical**: Fractals, quantum fields, Voronoi
- **Interactive**: Game elements, audio visualization

## Technical Implementation

### Shader Interface
All shaders implement the `effect_main(vec2 centered, vec2 uv)` function:
- `centered`: Normalized coordinates (-1 to 1), centered at origin
- `uv`: Standard UV coordinates (0 to 1)
- Returns: `vec4` color with alpha channel

### Base Utilities (`common.glsl`)
Key features include:
- **Uniforms**: Time, resolution, mouse, audio data, game state
- **Math Functions**: PI constants, hash functions, noise functions
- **SDF Primitives**: Sphere, box, torus, cylinder
- **SDF Operations**: Union, subtraction, intersection, smooth operations
- **Color Utilities**: HSV/RGB conversion, color mixing
- **Matrix Operations**: Rotation matrices for 3D transformations

### Performance Considerations

#### Optimization Techniques
- **Adaptive Ray Marching**: Variable step sizes based on distance
- **Early Termination**: Break loops when conditions are met
- **Spatial Sampling**: Reduced resolution for complex effects
- **Pre-computation**: Constants and reusable calculations

#### Performance Impact
- **High**: Ray marching effects (nebula, mandelbulb, raymarch_sculpture)
- **Medium**: Complex fractals, audio visualization
- **Low**: Simple patterns, gradients

## Organization & Recommendations

### Current Organization
- **Base**: Shared utilities and vertex shader
- **Effects**: Specialized visual effects
- **Simple**: Basic patterns and animations
- **Game**: Interactive game-like shaders

### Naming Conventions
- **Consistent**: Most shaders use descriptive names
- **Inconsistent**: Some files in root vs. effects directory
- **Metal Files**: Some .metal files present but not documented

### Recommended Improvements

#### 1. Directory Structure
```
shaders/
├── base/           # Shared utilities
├── effects/        # Complex visual effects
│   ├── fractals/    # Mandelbrot, Julia, Mandelbulb
│   ├── ray_marching/ # 3D ray marching effects
│   ├── audio/       # Audio-reactive shaders
│   ├── cellular/    # Voronoi, reaction diffusion
│   └── artistic/    # Abstract, quantum, DNA
├── patterns/       # Simple patterns (checkerboard, plasma)
├── interactive/    # Game and interactive shaders
└── special/        # Unique effects (flying toasters)
```

#### 2. File Naming
- Use consistent lowercase with underscores
- Include category prefix: `fractal_mandelbrot.frag`, `audio_spectrum.frag`
- Remove ambiguous names like `mandelbrot.frag` vs `mandelbrot_set.frag`

#### 3. Documentation Standards
- Add header comments to each shader
- Document all uniforms and parameters
- Include performance notes and complexity ratings
- Add visual examples or descriptions

#### 4. Code Organization
- Group related functions together
- Use consistent naming conventions
- Add error checking for edge cases
- Optimize for performance where possible

## Platform Considerations

### macOS (Metal)
- Uses Metal backend for native performance
- Supports .metal shader files
- Optimized for Apple Silicon SIMD

### Linux (OpenGL)
- Uses OpenGL 3.3+ backend
- Supports .frag and .vert GLSL files
- Cross-platform compatibility

### Cross-Platform Features
- All shaders work on both platforms
- Base utilities abstract platform differences
- Performance optimizations for each platform

## Development Guidelines

### Adding New Shaders
1. Choose appropriate category directory
2. Include header documentation
3. Use base utilities when possible
4. Test on both platforms
5. Add to documentation

### Performance Optimization
1. Use early termination in loops
2. Minimize expensive operations
3. Use efficient algorithms
4. Test performance on target hardware
5. Consider resolution scaling

### Best Practices
- Always include `#include "../base/common.glsl"`
- Use descriptive variable names
- Add comments for complex algorithms
- Test with different resolutions
- Monitor performance impact

This documentation provides a comprehensive reference for all ShaderCandy shaders, their functionality, and technical implementation details.