# ShaderCandy Linux Standalone Player

ShaderCandy Linux Standalone Player is a powerful application for browsing, viewing, and interacting with real-time procedural graphics shaders. Built with modern OpenGL and GLFW, it provides a seamless experience for exploring the full collection of ShaderCandy effects.

## Features

- **Modern OpenGL Rendering**: Uses OpenGL 3.3+ with core profile for optimal performance
- **Shader Management**: Automatic discovery and loading of all shader files
- **Audio Reactivity**: Real-time audio visualization with microphone input support
- **Interactive Controls**: Full keyboard and mouse support for navigation and manipulation
- **Performance Monitoring**: FPS counter, shader compilation time, and GPU metrics
- **Shader Parameters**: Live adjustment of shader uniforms and parameters
- **Hot Reloading**: Automatic shader reloading when source files change
- **Fullscreen Support**: Toggle between windowed and fullscreen modes
- **Cross-Platform**: Works on any Linux distribution with OpenGL support

## Requirements

- **Linux Distribution**: Ubuntu 18.04+, Debian 10+, Fedora 30+, or equivalent
- **Graphics**: OpenGL 3.3+ compatible GPU with up-to-date drivers
- **Dependencies**:
  - GLFW3 development libraries
  - OpenGL development libraries
  - ALSA development libraries (for audio)
  - CMake 3.10+ for building

## Installation

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y libglfw3-dev libgl1-mesa-dev libasound2-dev cmake
```

### Fedora
```bash
sudo dnf install -y glfw-devel mesa-libGL-devel alsa-lib-devel cmake
```

## Building

```bash
git clone https://github.com/yourusername/ShaderCandy.git
cd ShaderCandy
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

## Usage

```bash
# Basic usage
./shadercandy-player

# With audio support
./shadercandy-player --audio

# Start with specific shader
./shadercandy-player --shader nebula.frag

# Fullscreen mode
./shadercandy-player --fullscreen

# Custom window size
./shadercandy-player --width 1920 --height 1080
```

## Controls

### Navigation
- **Arrow Keys / Mouse Wheel**: Change shader
- **Home/End**: First/Last shader
- **Page Up/Down**: Jump 10 shaders
- **Number Keys (1-9)**: Jump to specific shader

### Shader Parameters
- **W/S**: Speed control (+/-)
- **A/D**: Intensity control (+/-)
- **R/F**: Resolution scaling (+/-)
- **T/G**: Time scale (+/-)

### Audio Controls
- **M**: Toggle audio reactivity
- **V**: Volume boost (+/-)
- **B**: Bass boost (+/-)
- **N**: Mid boost (+/-)
- **H**: Treble boost (+/-)

### Display Controls
- **F**: Toggle fullscreen
- **P**: Pause/resume animation
- **C**: Capture screenshot
- **L**: Reload current shader

### System Controls
- **ESC**: Quit application
- **Q**: Quit application
- **H**: Show help overlay

## Shader Collection

The player automatically discovers and loads shaders from these directories:
- `./shaders/` - Basic shaders
- `./shaders/effects/` - Advanced effects
- `/usr/share/shadercandy/shaders/` - System-wide shaders
- `/usr/local/share/shadercandy/shaders/` - Local system shaders

## Performance

- **Target FPS**: 60 (configurable)
- **Resolution**: Native window resolution
- **Audio**: 256-point FFT analysis
- **Memory**: Efficient UBO management with automatic cleanup

## Development

### Shader Development

When developing new shaders, the player supports hot reloading:
1. Edit shader source files
2. Press `L` to reload current shader
3. Or enable auto-reload in settings

### Adding New Shaders

1. Create new `.frag` file in `shaders/` or `shaders/effects/`
2. Include common utilities with `#include "../base/common.glsl"`
3. Use standard uniforms from `ShaderInterop.h`
4. Test with the standalone player

### Shader Uniforms

All shaders have access to these uniforms:
- `time`: Elapsed time in seconds
- `resolution`: Screen resolution (vec2)
- `mouse`: Mouse position (vec2)
- `audioData[256]`: Audio frequency spectrum
- `volume`, `bass`, `mid`, `treble`: Audio levels
- `beat`: Beat detection flag

## Troubleshooting

### Common Issues

1. **Black Screen**: Check OpenGL driver installation and compatibility
2. **Shader Compilation Errors**: Verify shader syntax and included files
3. **No Audio**: Ensure microphone permissions and ALSA configuration
4. **Low FPS**: Reduce resolution or disable expensive effects

### Debug Mode

```bash
./shadercandy-player --debug
```

This enables verbose logging and shader compilation output.

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

## Support

For issues and questions:
- Check the troubleshooting section
- Review the shader documentation
- Submit issues to the GitHub repository

---

**ShaderCandy Linux Standalone Player** - Explore the world of real-time procedural graphics!