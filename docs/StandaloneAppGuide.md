# ShaderCandy Standalone App Guide

## Overview

The ShaderCandy Standalone App is a companion macOS application that provides a windowed preview mode for ShaderCandy effects. Unlike the screensaver which runs full-screen, the standalone app allows you to:

- Preview shaders in a resizable window
- Quickly switch between shaders using the toolbar or keyboard shortcuts
- Adjust parameters in real-time
- Access preferences and settings
- Use shader presets

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy

# Build with CMake
mkdir build && cd build
cmake .. -DBUILD_STANDALONE_APP=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# The app will be at build/ShaderCandyPlayer.app
```

### Manual Installation

1. Download the latest `ShaderCandyPlayer.dmg` from the releases page
2. Open the DMG file
3. Drag `ShaderCandyPlayer.app` to your Applications folder
4. Launch from Applications or Launchpad

## Usage

### Launching

Double-click `ShaderCandyPlayer.app` to launch the standalone player. The app will:

1. Open a window with the default shader (plasma)
2. Initialize the Metal rendering engine
3. Load available shaders

### Window Controls

| Control | Action |
|---------|--------|
| Resize handle | Resize the preview window |
| Maximize button | Maximize to full screen |
| Close button | Quit the application |

### Toolbar

The toolbar provides quick access to common actions:

| Button | Description | Shortcut |
|--------|-------------|----------|
| Shader dropdown | Select active shader | - |
| Previous | Go to previous shader | ← |
| Next | Go to next shader | → |
| Shaders list | Toggle shader sidebar | ⌘L |
| Metrics | Toggle performance display | ⌘M |
| Settings | Open preferences | - |
| Full screen | Enter full screen mode | ⌘F |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Space | Switch to next shader |
| ← | Previous shader |
| → | Next shader |
| ↑ | Increase speed |
| ↓ | Decrease speed |
| ⌘L | Show/hide shader list |
| ⌘M | Show/hide metrics |
| ⌘F | Toggle full screen |
| ⌘, | Open preferences |
| ⌘Q | Quit application |

## Shader Selection

### Using the Toolbar

1. Click the shader dropdown in the toolbar
2. Select from the list of available shaders

### Using the Shader List

1. Press ⌘L or click the grid icon to show the shader list
2. Browse shaders organized by category:
   - **Fractals**: Mathematical fractals (mandelbulb, julia, etc.)
   - **Abstract**: Abstract visual effects (plasma, vortex, etc.)
   - **Space**: Cosmic and astronomical effects
   - **Effects**: Special effects (ripples, particles, etc.)
3. Click a shader to select it

### Using the Search Field

1. Show the shader list (⌘L)
2. Type in the search field to filter shaders
3. Select from the filtered list

## Preferences

Access preferences via ⌘, or the Settings button.

### Display Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Target FPS | Maximum frames per second | 60 |
| VSync | Synchronize with display refresh | On |
| HDR | Enable HDR rendering (if supported) | Off |
| Anti-Aliasing | MSAA sample count | Off |

### Audio Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Audio Reactivity | Respond to system audio | Off |
| Audio Sensitivity | Multiplier for audio response | 1.0 |
| Audio Smoothing | Smoothing factor for audio data | 0.3 |

### Performance Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Adaptive Quality | Dynamically adjust quality | On |
| FPS Threshold | Target FPS for quality scaling | 45 |
| Show FPS | Display frame rate overlay | Off |

### Shader Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Hot Reload | Reload shaders on file change | On |
| Default Shader | Shader to show on launch | plasma |

## Parameters

### Available Parameters

Each shader supports different parameters:

| Parameter | Range | Description |
|-----------|-------|-------------|
| Speed | 0.1 - 10.0 | Animation speed multiplier |
| Intensity | 0.1 - 5.0 | Effect intensity/amplitude |
| Gravity | 0.0 - 10.0 | Particle gravity (if applicable) |

### Adjusting Parameters

Parameters can be adjusted via:

1. **Preferences**: Set default values for all shaders
2. **Scripting**: Access via AppKit bindings
3. **Presets**: Save and load parameter combinations

## Presets

### Creating Presets

1. Adjust parameters to desired values
2. Go to File → Export Preset
3. Choose a name and location
4. The preset saves the current shader + parameters

### Loading Presets

1. Go to File → Import Preset
2. Select one or more `.json` preset files
3. The preset is applied immediately

### Preset Format

```json
{
  "version": "1.0",
  "name": "My Preset",
  "author": "User Name",
  "description": "A custom preset",
  "shader": "plasma",
  "parameters": {
    "speed": 1.5,
    "intensity": 1.0,
    "gravity": 0.5
  },
  "globalSettings": {
    "targetFPS": 60
  }
}
```

## Troubleshooting

### App Won't Start

**Problem**: App shows "Metal is not supported" error

**Solution**: ShaderCandy requires a Mac with Metal support:
- 2012 or later MacBook Pro
- 2012 or later MacBook Air
- 2013 or later Mac Pro
- 2014 or later Mac mini
- All Apple Silicon Macs

### Poor Performance

**Problem**: Low frame rates or stuttering

**Solutions**:
1. Reduce target FPS in preferences
2. Enable Adaptive Quality
3. Reduce window size
4. Disable HDR if enabled
5. Lower anti-aliasing setting

### Shaders Not Loading

**Problem**: Shaders don't appear in the list

**Solutions**:
1. Verify shaders directory: `~/Library/Application Support/ShaderCandy/shaders/`
2. Check console for shader compilation errors
3. Try a different shader

### Hot Reload Not Working

**Problem**: Shader changes aren't reflected

**Solutions**:
1. Verify Hot Reload is enabled in preferences
2. Check file permissions on shader files
3. Ensure shaders are in the correct directory

## Command Line

The standalone app supports limited command line arguments:

```bash
# Launch with specific shader
ShaderCandyPlayer.app/Contents/MacOS/ShaderCandyPlayer --shader mandelbulb_3d

# Launch fullscreen
ShaderCandyPlayer.app/Contents/MacOS/ShaderCandyPlayer --fullscreen

# Launch with custom shader directory
ShaderCandyPlayer.app/Contents/MacOS/ShaderCandyPlayer --shaders /path/to/shaders
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--shader <name>` | Start with specified shader |
| `--fullscreen` | Start in full screen mode |
| `--shaders <path>` | Use custom shader directory |
| `--fps <n>` | Set target FPS |
| `--help` | Show help message |

## Advanced

### Environment Variables

| Variable | Description |
|----------|-------------|
| `SHADERCANDY_FPS` | Override target FPS |
| `SHADERCANDY_DEBUG` | Enable debug logging |
| `SHADERCANDY_METAL_VALIDATION` | Enable Metal validation layers |

### Custom Shaders

Place custom shaders in:

- **User**: `~/Library/Application Support/ShaderCandy/shaders/`
- **System**: `/Library/Application Support/ShaderCandy/shaders/` (requires admin)

Shader file naming:
- Metal shaders: `*.metal`
- GLSL shaders: `*.glsl` or `*.frag`

### Performance Monitoring

Enable metrics display (⌘M) to see:

- Current FPS
- GPU time (ms)
- Dropped frames
- Memory usage

## Support

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Get help from the community
- **Wiki**: Find additional guides and tutorials

## System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| macOS | Ventura 13.0 | Sonoma 14.0+ |
| Memory | 4 GB | 8 GB+ |
| GPU | Metal support | Apple Silicon |
| Display | Any | HDR-capable |

## License

ShaderCandy is licensed under the MIT License. See LICENSE for details.
