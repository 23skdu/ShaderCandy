# Fallout Shader Documentation

## Overview

The `fallout.metal` shader creates a dramatic nuclear blast and mushroom cloud effect. It simulates:

- **Fireball**: A pulsing sphere of nuclear plasma at ground zero
- **Mushroom Cloud**: Rising smoke with realistic billowing motion
- **Smoke Trails**: Upward-flowing debris trails
- **Nuclear Flash**: Intense flash effect synchronized with audio
- **Shockwave**: Expanding ring of pressure
- **Radiation Glow**: Pulsing ground illumination
- **Embers**: Audio-reactive particle effects

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `speed` | 0.1 - 5.0 | 1.0 | Animation speed multiplier |
| `intensity` | 0.1 - 3.0 | 1.0 | Effect brightness and scale |
| `gravity` | 0.0 - 10.0 | 1.0 | Smoke rise speed (affects physics) |
| `audioBass` | 0.0 - 1.0 | 0.0 | Audio bass response (impacts fireball/embers) |
| `audioMid` | 0.0 - 1.0 | 0.0 | Audio mid response (impacts flash) |
| `audioTreble` | 0.0 - 1.0 | 0.0 | Audio treble response (impacts shockwave) |

## Audio Reactivity

The fallout shader responds to audio input:

| Audio Band | Effect |
|------------|--------|
| **Bass** | Fireball intensity, ember particle count |
| **Mid** | Flash brightness, mushroom cloud turbulence |
| **Treble** | Shockwave speed, overall glow pulse |

## Animation Loop

The shader runs on a 5-second loop:
- 0.0s: Initial explosion flash
- 0.5-1.0s: Fireball peaks
- 1.0-3.0s: Mushroom cloud rises
- 3.0-5.0s: Smoke dissipates, then resets

## Technical Details

### Shader Functions

| Function | Purpose |
|----------|---------|
| `mushroomCloudSDF` | Signed distance field for mushroom shape |
| `fireballSDF` | SDF with turbulence for fireball |
| `smokeDensity` | Volumetric smoke accumulation |
| `flashIntensity` | Nuclear flash calculation |
| `nuclearPalette` | Fire color gradient (white→yellow→orange→red) |
| `groundGlow` | Radiation glow on ground plane |

### Color Palette

The shader uses a procedural nuclear color palette:

```
White (hottest) → Yellow → Orange → Red → Dark Red → Smoke Gray
```

### Performance Notes

| Setting | Performance Impact |
|---------|-------------------|
| High `intensity` | Minor - more glow calculations |
| Audio enabled | Minor - additional FFT processing |
| 4K resolution | Moderate - more fragment calculations |

## Usage Examples

### Standalone App

```objc
// Set fallout as active shader
[renderer setActiveShader:@"fallout" error:nil];

// Adjust for dramatic effect
view.speed = 2.0;
view.intensity = 1.5;

// Enable audio reactivity
[renderer setAudioReactivityEnabled:YES];
```

### Preset Export

```json
{
  "version": "1.0",
  "name": "Nuclear Sunset",
  "shader": "fallout",
  "parameters": {
    "speed": 0.8,
    "intensity": 2.0,
    "gravity": 0.5
  },
  "globalSettings": {
    "targetFPS": 60
  }
}
```

## Tips

1. **For maximum impact**: Set `intensity` to 2.0+ with audio enabled
2. **Calm version**: Set `speed` to 0.5, `intensity` to 0.8
3. **Audio sync**: Use music with strong bass for best ember effects
4. **Full screen**: Best experienced in full-screen mode

## Technical Requirements

- **Metal**: macOS 10.11+ (macOS 12.0+ for best performance)
- **GPU**: Any Metal-capable Mac
- **Memory**: ~50MB for shader and textures
