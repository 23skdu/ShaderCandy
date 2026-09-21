# Getting Started with ShaderCandy

## Quick Install

```bash
# Build from source
git clone https://github.com/23skdu/ShaderCandy.git
cd ShaderCandy
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=ON
cmake --build . -j$(nproc)

# Run tests
./shadercandy-test

# Install (optional)
sudo cmake --install .
```

## Dependencies

- **Build**: CMake 3.20+, C++17 compiler, pkg-config
- **Linux**: libx11-dev, libxss-dev, libgl-dev, libpulse-dev, libfftw3-dev
- **Optional**: GLFW (for standalone player), Wayland dev libs (for Wayland mode)

## Running

### Standalone Player
```bash
./shadercandy-player
# Browse shaders with arrow keys, F for fullscreen, ESC to quit
```

### X11 Screensaver
```bash
# Run directly on root window
./shadercandy-screensaver -root

# Integrate with XScreenSaver
echo "programs: \n  shadercandy-screensaver -root \\n" >> ~/.xscreensaver
```

### Wayland
```bash
./shadercandy-wayland
# Sway: assign to layer-shell background
```

### Wallpaper Mode
```bash
./shadercandy-wallpaper --shader ./shaders/effects/plasma.frag
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Right / Space / P | Next shader |
| Left / N | Previous shader |
| S | Toggle shuffle |
| F | Toggle favorite |
| X | Skip current shader |
| E | Cycle easing mode |
| Shift+T | Cycle transition type |
| 1-5 | Adjust shader parameters |
| Ctrl+S / Ctrl+O | Save / load preset |
| D | Toggle debug overlay |
| F12 | Screenshot |
| ESC / Q | Quit |

## Writing Custom Shaders

Create a `.frag` file with:

```glsl
// My Shader - A brief description
// Category: Effects
// Parameter: intensity 0.0 2.0 1.0 Adjusts visual intensity

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    float v = sin(uv.x * 10.0 + time * speed) * 0.5 + 0.5;
    fragColor = vec4(v * intensity, 0.3, 0.5, 1.0);
}
```

Place it in `~/.local/share/shadercandy/shaders/` or pass `-shader-dir` to the player.

## Configuration

Settings are stored in `~/.config/shadercandy/settings.json`:

```json
{
  "targetFPS": 60,
  "vsync": true,
  "enableAudio": false,
  "audioSensitivity": 1.0
}
```

## Further Reading

- [Architecture Overview](./ArchitectureDiagrams.md)
- [Linux Platform Features](./LinuxFeatures.md)
- [Shader Authoring Guide](./ShaderAuthoringGuide.md)
- [Application Modes Guide](./ApplicationModesGuide.md)
