# ShaderCandy Linux Features

This document describes the Linux-specific features implemented for ShaderCandy.

## Overview

ShaderCandy on Linux now supports the following features that were previously macOS-only:

1. **Audio Reactivity** - Real-time audio input with FFT spectrum analysis
2. **Standalone Player** - Windowed application for browsing shaders
3. **Wallpaper Mode** - Set shaders as desktop background
4. **Hot Reloading** - Automatic shader recompilation on file changes

## Audio Reactivity

The Linux audio implementation uses ALSA for audio capture and FFTW3 for Fast Fourier Transform processing.

### Requirements

```bash
# Debian/Ubuntu
sudo apt-get install libasound2-dev libfftw3-dev

# Fedora
sudo dnf install alsa-lib-devel fftw-devel

# Arch Linux
sudo pacman -S alsa-lib fftw
```

### Usage

Enable audio reactivity with the `-audio` flag:

```bash
# Screensaver with audio
shadercandy-screensaver -audio

# Standalone player with audio
shadercandy-player -audio

# Wallpaper with audio
shadercandy-wallpaper -shader ./shaders/audio_spectrum.frag -audio
```

### Audio Uniforms

When audio is enabled, the following uniforms are available in shaders:

```glsl
uniform float volume;       // Overall volume (0.0 - 1.0)
uniform float bass;         // Bass frequency energy (0.0 - 1.0)
uniform float mid;          // Mid frequency energy (0.0 - 1.0)
uniform float treble;       // Treble frequency energy (0.0 - 1.0)
uniform float beat;         // Beat detection (1.0 on beat, 0.0 otherwise)
uniform float audioData[256]; // FFT spectrum data
```

See `shaders/effects/audio_spectrum.frag` for an example audio-reactive shader.

## Standalone Player

The standalone player (`shadercandy-player`) is a windowed application for browsing and viewing shaders outside of screensaver mode.

### Features

- Browse through available shaders with arrow keys or mouse wheel
- Fullscreen toggle (F or F11)
- Pause/Resume animation (Space)
- Reload current shader (R)
- Audio reactivity support (-audio flag)
- Shader hot-reloading

### Usage

```bash
# Basic usage
shadercandy-player

# Start with specific shader
shadercandy-player -shader nebula

# Start fullscreen with audio
shadercandy-player -fullscreen -audio

# Custom window size
shadercandy-player -width 1920 -height 1080

# Show help
shadercandy-player --help
```

### Controls

| Key | Action |
|-----|--------|
| Arrow Keys / Mouse Wheel | Change shader |
| F / F11 | Toggle fullscreen |
| Space | Pause/Resume animation |
| R | Reload current shader |
| ESC | Quit |

## Wallpaper Mode

The wallpaper mode (`shadercandy-wallpaper`) renders shaders as your desktop background.

### Requirements

- X11 with composite extension (for transparency)
- A compositor running (compton, picom, etc.)
- Optional: xwinwrap for better desktop integration

### Usage

```bash
# Basic usage (requires compositor)
shadercandy-wallpaper -shader ./shaders/nebula.frag

# With audio reactivity
shadercandy-wallpaper -shader ./shaders/audio_spectrum.frag -audio

# Using xwinwrap (recommended for better compatibility)
xwinwrap -ov -fs -- shadercandy-wallpaper -shader ./shaders/plasma.frag

# With audio via xwinwrap
xwinwrap -ov -fs -- shadercandy-wallpaper -shader ./shaders/audio_spectrum.frag -audio
```

### Desktop Integration

For persistent wallpaper across reboots, add to your window manager's startup scripts:

```bash
# ~/.xinitrc or ~/.xsession
xwinwrap -ov -fs -- shadercandy-wallpaper -shader /usr/share/shadercandy/shaders/nebula.frag &
```

### Tips

- Use shaders with darker colors for better desktop icon visibility
- The `nebula.frag` and `deep_ocean_pulse.frag` shaders work well as wallpapers
- Audio-reactive wallpapers work best with ambient/electronic music

## Building

### Prerequisites

All features require:
```bash
sudo apt-get install build-essential cmake pkg-config
sudo apt-get install libx11-dev libgl1-mesa-dev libxcomposite-dev libxrender-dev
```

Audio features additionally require:
```bash
sudo apt-get install libasound2-dev libfftw3-dev
```

Standalone player additionally requires:
```bash
sudo apt-get install libglfw3-dev
```

### Compile

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Install
sudo make install
```

### Build Options

```bash
# Disable audio support
cmake .. -DBUILD_AUDIO=OFF

# Disable standalone player
cmake .. -DBUILD_STANDALONE_PLAYER=OFF

# Disable wallpaper mode
cmake .. -DBUILD_WALLPAPER=OFF
```

## Troubleshooting

### No audio input detected

1. Check ALSA is installed: `arecord -l`
2. Check microphone permissions: `pactl list sources`
3. Try specifying a device: Modify the auto-detect code or use `hw:0,0`

### Wallpaper doesn't appear

1. Ensure a compositor is running: `pgrep compton || pgrep picom`
2. Try with xwinwrap: `xwinwrap -ov -fs -- shadercandy-wallpaper ...`
3. Check XComposite extension: `xdpyinfo | grep -i composite`

### Shader compilation errors

1. Check OpenGL 3.3+ support: `glxinfo | grep "OpenGL version"`
2. Verify shader file exists and is readable
3. Check shader syntax with `glslangValidator` if available

### Performance issues

1. Reduce resolution for fullscreen modes
2. Disable audio if not needed
3. Use simpler shaders (avoid heavy raymarching)
4. Ensure GPU drivers are up to date

## Differences from macOS Version

The Linux implementation differs from macOS in the following ways:

| Feature | macOS | Linux |
|---------|-------|-------|
| Audio API | AVFoundation | ALSA + FFTW3 |
| Windowing | AppKit/MetalKit | X11 + OpenGL |
| Standalone UI | Native AppKit | GLFW (planned: ImGui) |
| Wallpaper | Native NSWindow | X11 override_redirect |
| Neural Effects | CoreML | Not available |
| HDR | 10-bit Metal | Limited OpenGL support |
| Ray-Traced Audio | Yes | Not available |

## Future Enhancements

Planned improvements for Linux:

1. **ImGui Integration** - Add proper shader browser UI to standalone player
2. **Wayland Support** - Native Wayland backend
3. **PipeWire** - Alternative to ALSA for audio
4. **HDR Support** - 10-bit color via OpenGL
5. **Multi-Monitor** - Per-monitor wallpapers and improved sync

## See Also

- [MASTER_STATUS_AND_ROADMAP.md](../docs/MASTER_STATUS_AND_ROADMAP.md) - Overall project status
- [LINUX_PORT_SUMMARY.md](../docs/archive/LINUX_PORT_SUMMARY.md) - Original Linux port details
- [SHADER_TRANSLATION_STANDARDS.md](../docs/SHADER_TRANSLATION_STANDARDS.md) - Metal to GLSL translation guide
