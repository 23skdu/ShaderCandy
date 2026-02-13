# Architecture & Foundation Master Plan

## Overview

This document consolidates the core architectural decisions and foundation implementation details for ShaderCandy, combining insights from the master project plan and Phase 1 implementation.

## Core Architecture Decisions

### 1. Cross-Platform Design

**Decision**: Unified C++ abstraction layer with platform-specific backends

**Rationale**: Enables code reuse while allowing platform-specific optimizations

**Implementation**:
- `src/core/` - Platform-independent logic (UniformBuffer, PerformanceMonitor, ShaderManager)
- `src/platform/macos/` - Metal backend with ScreenSaverView integration
- `src/platform/linux/` - OpenGL/X11 backend with XScreenSaver integration

### 2. Shader Abstraction Layer

**Decision**: Shared GLSL/Metal shader utilities with common interface

**Rationale**: Enables shader portability while maintaining platform-specific optimizations

**Implementation**:
- `shaders/base/common.metal` - 200+ lines of Metal utilities
- `shaders/base/common.glsl` - Identical functionality for OpenGL
- `shaders/base/vertex.glsl` - Standard fullscreen quad vertex shader

### 3. SIMD Optimization Strategy

**Decision**: Runtime CPU architecture detection with function dispatch

**Rationale**: Maximize performance while maintaining compatibility

**Implementation**:
- ARM NEON for Apple Silicon
- AVX2 for x86_64
- Fallback scalar implementations
- Automatic dispatch based on compile-time detection

## Foundation Implementation Details

### 1. Core Components

#### UniformBuffer
- Cross-platform uniform data structure
- Time tracking (total and delta)
- Resolution management
- Mouse position tracking
- Date/time stamping
- Frame counting

#### PerformanceMonitor
- Frame time tracking with history
- FPS calculation (current, average, min, max)
- 99th percentile frame time
- Dropped frame detection
- Rolling window statistics

#### ShaderManager
- Abstract base class for platform-specific implementations
- Hot reload support
- Shader registry
- Change callbacks

### 2. Build System Architecture

**Decision**: CMake 3.20+ with conditional compilation

**Rationale**: Cross-platform compatibility with modern C++ features

**Features**:
- Platform detection (macOS/Linux)
- Conditional compilation options
- Automatic SIMD flag detection
- Metal backend support (macOS)
- OpenGL backend support (Linux)
- Screensaver bundle creation (macOS)
- Executable creation (Linux)
- Shader installation
- Test framework integration

### 3. Shader Framework

#### Base Utilities (200+ lines each)
- Hash functions (1D, 2D, 3D)
- Noise functions (Perlin, Simplex 3D)
- FBM (Fractal Brownian Motion)
- Color utilities (HSV↔RGB conversion)
- SDF primitives (sphere, box, torus)
- SDF operations (union, subtraction, intersection, smooth variants)
- Rotation matrices (X, Y, Z axes)

#### Example Shaders
- **Nebula**: Volumetric clouds with stars
- **Ray March Sculpture**: Abstract SDF geometry
- **Mandelbulb**: 3D fractal
- **Reaction-Diffusion**: Gray-Scott patterns

## Platform-Specific Architecture

### macOS Implementation

**ScreenSaverView Integration**:
- Full ScreenSaverView subclass with MTKViewDelegate
- Metal device initialization and command queue management
- Automatic shader discovery from bundle resources
- Real-time uniform updates
- Triple-buffered uniform buffers for performance
- Hot reload support with file modification checking
- Configuration sheet support
- 60fps rendering with CADisplayLink timing

**Metal Backend**:
- PIMPL idiom for clean API/implementation separation
- Support for both source compilation and metallib loading
- Pipeline state management
- Viewport control
- Performance metrics tracking
- Shader directory monitoring for hot reload
- Move semantics for resource management

### Linux Implementation

**X11 Integration**:
- Full X11 integration with GLX context creation
- Modern OpenGL (3.3+) with framebuffer configuration selection
- Window creation with proper colormap
- Fullscreen quad geometry setup
- VAO/VBO management
- Shader loading from files
- Event handling (keyboard, mouse, resize)
- ~60fps frame rate limiting
- Proper cleanup on exit

**GL Shader Wrapper**:
- Vertex/fragment shader compilation
- Program linking
- Uniform Buffer Object management
- Automatic uniform updates
- Error reporting

## Development Workflow

### Hot Reload System
- File watchers for automatic recompilation
- Runtime shader compilation on both platforms
- Error fallback to previous working shader

### Testing Framework
- Auto-registration via REGISTER_TEST_SUITE macro
- Comprehensive assertion macros
- Timing measurement per test
- Pass/fail reporting with colored output
- Summary statistics
- CLI interface with options

### CI/CD Pipeline
- GitHub Actions for automated builds
- Multi-platform artifact collection
- Shader validation and compilation tests
- Performance regression testing

## Future Architecture Considerations

### Phase 4: Expansion & Distribution
- Standalone app player with UI
- Active wallpaper mode with multi-monitor support
- Preset export/import system
- Neural effects with CoreML integration

### Phase 5: Advanced Tech
- Ray-traced audio with acoustic simulation
- HDR mastery with 10-bit color support
- Build system and CI/CD updates
- Comprehensive documentation and user guides

## Success Metrics

### Performance Targets
- 60fps on Apple M2 with all features enabled
- 30fps on Intel Mac with neural effects
- <5% CPU usage for audio processing
- Frame-level synchronization across multi-display setups

### Quality Targets
- Zero crashes or memory leaks
- Comprehensive test coverage (≥90%)
- Cross-platform visual parity
- Hot reload with error recovery

---

*This document represents the consolidated architectural foundation as of February 2026. All implementation details reflect actual codebase state rather than planned features.*