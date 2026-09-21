# ShaderCandy Linux Architecture & Platform Features

This document provides a technical overview of the Linux architecture, display server backends, audio drivers, and build configurations in ShaderCandy.

---

## 1. Linux Graphics & Audio Architecture

ShaderCandy on Linux runs on modern 64-bit Linux distributions with full support for both legacy X11 and native Wayland environments:

```mermaid
flowchart TD
    App[Linux Application Entry Points\nscreensaver / player / wallpaper / wayland] --> DisplaySelect{Display Server}

    subgraph "Display & Windowing Subsystem"
        DisplaySelect -->|X11 Session| X11["X11 Backend\n(Xlib / GLX / XScreenSaver / XComposite)"]
        DisplaySelect -->|Wayland Session| WL["Wayland Backend\n(EGL / wlr-layer-shell / ext-idle-notify)"]
        DisplaySelect -->|Standalone GLFW| GLFW["GLFW Window Manager\n(X11 & Wayland EGL)"]
    end

    subgraph "Rendering Core"
        X11 & WL & GLFW --> GL["GLRenderer (OpenGL 3.3+ Core Profile)"]
        GL --> UL["UniformUploader\n(cached uniform location dispatch,\nShaderParams + audioData[256])"]
        UL --> Prog["GLShaderProgram\n(Auto-init LDR, reload support)"]
        Prog --> GLSL["GLSLWrapper\n(#include resolver with mtime cache)"]
        GL --> Trans["Transition System\n(10 types, 10 easing functions)"]
    end

    subgraph "Post-Processing Pipeline"
        GL --> Bloom["Bloom Pipeline\n(threshold → blur passes → composite)"]
        Bloom --> FBO["FBO Post-Processing\n(offscreen render → tone map → screen)"]
        GL --> PP["Full-Screen Effects\n(vignette, chromatic aberration,\nfilm grain, CRT scanlines, color tint)"]
        PP --> FBO
    end

    subgraph "File Watcher"
        GL --> Watcher["inotify-based File Watcher\n(IN_MODIFY, 100ms poll)"]
        Watcher -->|Modified| Prog
    end

    subgraph "Capture & Encoding"
        GL --> HR["HeadlessRenderer"]
        HR --> Ffmpeg["ffmpeg Video Encoding\n(PNG / JPG / PPM output)"]
    end

    subgraph "Audio Capture Subsystem"
        Audio["System Audio / Microphone"] --> AudioChoice{Audio Backend}
        AudioChoice -->|Default| PW["PulseAudio / PipeWire\n(preferred via CMake)"]
        AudioChoice -->|Fallback| ALSA["ALSA Direct Capture + FFTW3"]
        PW & ALSA --> FFT["Spectral Analysis (256 FFT Bins, Bass/Mid/Treble/Beat)"]
        FFT --> AU["Audio Utils\n(packAudioForShader, getDominantFrequency,\ngetSpectralCentroid, bandHasEnergy)"]
    end

    GL & AU --> Core["ShaderCandy Core Modules (src/core/)"]
```

---

## 2. Key Linux Features

1. **Native Wayland Support**: Direct surface allocation and protocol handling via EGL and Wayland layer-shell (`wlr-layer-shell-unstable-v1` / `ext-idle-notify-v1`) for modern compositors (Sway, Hyprland, GNOME, KDE Plasma 6).
2. **X11 Screensaver & Root Window Integration**: Seamless attachment to XScreenSaver or direct root window rendering via XComposite extension.
3. **Low-Latency Audio Reactivity**: Direct ALSA sample capture processed through FFTW3 with 256 spectrum bins and beat detection.
4. **Standalone Player & Wallpaper Modes**: Full windowed browser and dynamic live desktop background. *(For user controls and configuration, see [ApplicationModesGuide.md](./ApplicationModesGuide.md)).*
5. **inotify-Based Shader Hot Reloading**: Uses Linux `inotify` (not timestamp polling) to detect file modifications on loaded shaders, with automatic `#include` cache invalidation via mtime checks.
6. **Bloom Post-Processing**: FBO-based bloom pipeline with configurable quality levels (Low=2 passes, Medium=4, High=6, Ultra=8 Gaussian blur passes).
7. **Headless Rendering & Video Encoding**: `HeadlessRenderer` pipes RGBA frames to ffmpeg via `popen()` for PNG/JPG/PPM video output.
8. **GLRendererTypes.h**: Extracted GL-only structs and enums (GLBloomConfig, GLParticleConfig, GLPerformanceMetrics, GLRendererError, GLTransitionType, GLEasingFunction, GLTransitionConfig, GLPostProcessConfig, GLAdaptiveQualityConfig) for testability without GL dependencies.
9. **UniformUploader**: Cached uniform location dispatch that replaces 30+ lines of manual per-uniform location queries. Now uploads ShaderParams (param1-6, colorPalette, effectFlags) and full audioData[256] array. Guards against null GL function pointers in headless mode.
10. **Transition System**: Configurable shader-to-shader transitions with 10 transition types (Crossfade, Dissolve, Wipe directions, Zoom, Spin) and 10 easing functions (Linear, EaseIn/Out, Cubic, Exponential variants).
11. **Post-Processing Pipeline**: Full-screen effects via `GLPostProcessConfig`: vignette, chromatic aberration, film grain, CRT scanlines, and color tint — each independently toggleable with intensity parameters.
12. **Adaptive Quality**: `GLAdaptiveQualityConfig` dynamically scales resolution to maintain target FPS, with configurable min/max resolution scale bounds and FPS thresholds.
13. **Smart Shader Rotation**: Shuffle mode, favorites/skip lists, and auto-rotate with configurable per-shader duration for hands-free browsing.

## 3. Adaptive Quality & Smart Rotation

### Adaptive Quality

`GLAdaptiveQualityConfig` in `GLRendererTypes.h` provides dynamic resolution scaling to maintain a target frame rate:

| Field | Type | Description |
| :--- | :--- | :--- |
| `enabled` | bool | Toggle adaptive quality on/off |
| `targetFPS` | int | Desired frame rate (default: 60) |
| `lowFPS` | int | FPS threshold below which resolution scales down |
| `highFPS` | int | FPS threshold above which resolution scales up |
| `minResolutionScale` | float | Minimum resolution multiplier (e.g. 0.5 = half res) |
| `maxResolutionScale` | float | Maximum resolution multiplier (e.g. 1.0 = full res) |
| `currentResolutionScale` | float | Current active resolution scale |

### Smart Shader Rotation

Configurable automatic shader cycling for hands-free operation:

- **Shuffle Mode**: Randomize shader traversal order.
- **Favorites List**: Only rotate through pinned shaders.
- **Skip List**: Exclude specific shaders from rotation.
- **Auto-Rotate Interval**: Configurable per-shader duration before transitioning.

---

## 4. Audio Reactivity

The Linux audio implementation utilizes ALSA for direct hardware sample streaming and FFTW3 for Fast Fourier Transform spectral decomposition.

### Uniform Layout in GLSL Shaders

When audio is enabled (via the `-audio` CLI flag), the following global uniforms are available in shaders:

```glsl
uniform float volume;          // Overall audio volume (0.0 - 1.0)
uniform float bass;            // Low frequency energy (20-250 Hz, 0.0 - 1.0)
uniform float mid;             // Mid frequency energy (250-4000 Hz, 0.0 - 1.0)
uniform float treble;          // High frequency energy (4000-16000 Hz, 0.0 - 1.0)
uniform float beat;            // Beat detection pulse (1.0 on beat, 0.0 otherwise)
uniform float audioData[256];  // Raw FFT magnitude spectrum
```

### Audio Utils API

| Function | Description |
| :--- | :--- |
| `packAudioForShader(volume, bass, mid, treble, beat, audioData)` | Packs all audio data into the shader uniform buffer |
| `getDominantFrequency(audioData, sampleRate)` | Returns the dominant frequency from FFT spectrum |
| `getSpectralCentroid(audioData)` | Returns the spectral centroid (brightness measure) |
| `bandHasEnergy(audioData, lowHz, highHz, sampleRate)` | Checks if a frequency band has significant energy |

### Usage Examples
```bash
# Screensaver with audio visualization
shadercandy-screensaver -audio

# Standalone player with audio
shadercandy-player -shader electronic -audio

# Live wallpaper with audio
shadercandy-wallpaper -shader ./shaders/effects/audio_spectrum.frag -audio
```

---

## 5. Wayland Compositor Integration

ShaderCandy provides first-class native Wayland support without requiring XWayland.

### Supported Compositors
- **Sway**: Native `wlr-layer-shell` support.
- **Hyprland**: Full layer-shell and fractional scaling support.
- **GNOME Shell**: Wayland session compatible.
- **KDE Plasma 6**: Native Wayland idle detection and lock-screen support.
- **River / Wayfire**: Standard wlroots-based compositors.

### Wayland Launch Commands
```bash
# Launch default screensaver under Wayland
shadercandy-wayland

# Target specific shader
shadercandy-wayland --shader ./shaders/effects/nebula.frag

# Query available shaders
shadercandy-wayland --list
```

---

## 6. Building on Linux

### Requirements
- **CMake 3.20+**
- **C++17** compiler (GCC 8+ or Clang 7+)

### Package Dependencies

#### Debian / Ubuntu / Mint
```bash
# Core build tools and X11
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config \
    libx11-dev libgl1-mesa-dev libxcomposite-dev libxrender-dev libxext-dev

# Audio support
sudo apt-get install -y libasound2-dev libfftw3-dev

# Standalone player (GLFW)
sudo apt-get install -y libglfw3-dev

# Wayland support
sudo apt-get install -y libwayland-dev libegl-dev libgles2-dev libwayland-egl1-mesa
```

#### Fedora / RHEL
```bash
sudo dnf install -y gcc-c++ cmake pkgconfig \
    libX11-devel mesa-libGL-devel libXcomposite-devel libXrender-devel \
    alsa-lib-devel fftw-devel glfw-devel \
    wayland-devel mesa-libEGL-devel mesa-libGLES-devel
```

#### Arch Linux / Manjaro
```bash
sudo pacman -S --needed base-devel cmake pkgconf \
    libx11 mesa libxcomposite libxrender \
    alsa-lib fftw glfw-x11 \
    wayland mesa libglvnd
```

### Compilation

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17
make -j$(nproc)

# Install binaries to /usr/local/bin
sudo make install
```

### CMake Build Flags

| Option | Default | Description |
| :--- | :---: | :--- |
| `BUILD_SCREENSAVER_LINUX` | `ON` | Build X11 screensaver (`shadercandy-screensaver`) |
| `BUILD_SCREENSAVER_WAYLAND`| `ON` | Build Wayland screensaver (`shadercandy-wayland`) |
| `BUILD_STANDALONE_PLAYER` | `ON` | Build GLFW windowed player (`shadercandy-player`) |
| `BUILD_WALLPAPER` | `ON` | Build desktop wallpaper (`shadercandy-wallpaper`) |
| `BUILD_AUDIO` | `ON` | Enable ALSA and FFTW3 audio reactivity |
| `BUILD_TESTS` | `ON` | Build unit test and regression suite (`shadercandy-test`)|

---

## 7. Linux Differences from macOS

| Architectural Area | macOS Backend | Linux Backend | Design Rationale |
| :--- | :--- | :--- | :--- |
| **Graphics API** | Metal 3 | OpenGL 3.3+ Core / 4.5 | Direct hardware access on Apple Silicon vs universal Linux driver support |
| **Display Server** | AppKit / Quartz / MetalKit | Wayland / X11 | Dual backend ensures compatibility on legacy X11 and modern Wayland |
| **Audio Input** | AVFoundation | ALSA / PipeWire + FFTW3 | Native driver capture with zero runtime overhead |
| **Audio Ray-Tracing** | Metal Performance Shaders | Simplified Acoustic Model | MPS relies on Apple Silicon hardware ray-tracing |
| **Bloom Post-Processing** | Compute-based (Metal tile memory) | FBO-based (configurable blur passes) | Different GPU memory architectures |
| **Hot Reloading** | File timestamp polling | inotify (IN_MODIFY events) | inotify provides OS-level file change notifications |
| **Uniform Upload** | Metal buffer bindings | UniformUploader (cached locations) | Eliminates redundant `glGetUniformLocation` calls |
| **Neural Effects** | Apple Neural Engine (CoreML)| Not Supported | CoreML is proprietary to Apple Silicon hardware |
| **HDR Output** | EDR up to 1600 nits (10-bit) | FBO-based bloom + tone mapping | Consistent tone mapping without fragile driver requirements |
| **Video Encoding** | Screen capture APIs | ffmpeg via popen pipe | Cross-platform video output via ffmpeg |
| **Note on Vulkan** | N/A | Evaluated & Retired | Vulkan was removed in favor of robust OpenGL 3.3+/Wayland integration |

---

## 8. Troubleshooting

### Audio Not Reacting
1. List available recording devices: `arecord -l`
2. Check ALSA capture levels: `alsamixer` (ensure Capture volume is not muted).
3. If using PipeWire: verify `pipewire-alsa` compatibility package is installed.

### Wallpaper Mode Does Not Render
1. Verify compositor is active: `pgrep -a picom || pgrep -a compton`
2. Use the `xwinwrap` wrapper to bypass window manager desktop icon painting:
   ```bash
   xwinwrap -ov -fs -- shadercandy-wallpaper -shader ./shaders/effects/plasma.frag
   ```

### GLSL Compilation Errors
1. Validate fragment shader syntax directly with `glslangValidator`:
   ```bash
   glslangValidator -S frag shaders/effects/your_shader.frag
   ```
2. Verify OpenGL driver version: `glxinfo | grep "OpenGL version"` (must be $\ge 3.3$).

### Hot Reload Not Working
1. Ensure inotify is available in your kernel: `lsmod | grep inotify`
2. Check that the shader file is actually being watched (file must be loaded first).
3. The include cache is invalidated by file mtime -- modifying included files (e.g. `common.glsl`) will trigger recompilation.

---

## 9. See Also

- **[ApplicationModesGuide.md](./ApplicationModesGuide.md)**: Usage guide for player, wallpaper, and screensaver modes.
- **[ShaderAuthoringGuide.md](./ShaderAuthoringGuide.md)**: Developer guide for creating and translating GLSL shaders.
- **[ShaderCandyMasterPlan.md](./ShaderCandyMasterPlan.md)**: Master architecture plan and feature matrix.
- **[nextsteps.md](./nextsteps.md)**: Active engineering roadmap.
