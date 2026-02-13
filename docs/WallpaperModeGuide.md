# ShaderCandy Wallpaper Mode Guide

## Overview

ShaderCandy can render live animated wallpapers on your macOS desktop, replacing static desktop backgrounds with dynamic procedural graphics.

## Features

- **Live Rendering**: Real-time GPU-accelerated wallpaper rendering
- **Multi-Monitor Support**: Different shaders per display
- **Space Integration**: Per-Space wallpaper assignments
- **Power Aware**: Automatic pause on battery
- **Performance Options**: Adjustable quality and frame rate

## Installation

### Enable Wallpaper Mode

```bash
# Build and install screensaver
mkdir build && cd build
cmake .. && make
./install_macos.sh

# Enable wallpaper mode
ShaderCandyPlayer.app/Contents/MacOS/ShaderCandyPlayer --wallpaper
```

### System Preferences

1. Open System Settings → Desktop & Screen Saver
2. Select ShaderCandy from Screen Savers
3. Configure in Screen Saver Options

## Usage

### Basic Configuration

```objc
WallpaperEngine *engine = [WallpaperEngine sharedEngine];
[engine start];

// Set shader for all desktops
[engine setWallpaperForAllDesktops:@"nebula"];

// Set different shader per display
[engine setWallpaperForDesktop:@"Display1" withShader:@"plasma"];
[engine setWallpaperForDesktop:@"Display2" withShader:@"mandelbulb_3d"];
```

### Per-Space Wallpapers

```objc
WallpaperSpaceManager *spaceManager = [WallpaperSpaceManager sharedManager];

// Assign shader to specific Space
[spaceManager setShader:@"vortex" forSpace:@"Space1"];

// Get current assignments
NSDictionary *assignments = spaceManager.allAssignments;
```

### Power Management

```objc
// Enable battery awareness
engine.pauseOnBattery = YES;

// Set target FPS (lower = less power)
engine.targetFPS = 30;
```

## Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| Target FPS | 30 | Frame rate for wallpaper |
| Quality | High | Rendering quality level |
| Pause on Battery | Yes | Stop when unplugged |
| Audio Reactivity | No | Respond to system audio |
| HDR | Auto | Enable on HDR displays |

## Performance

### Recommended Settings

| Hardware | FPS | Quality | Notes |
|----------|-----|---------|-------|
| Apple Silicon | 30 | High | Default settings |
| Intel Mac | 15 | Medium | Reduce for battery |
| Older Mac | 10 | Low | Minimal impact |

### Reducing CPU/GPU Usage

```objc
// Lower frame rate
engine.targetFPS = 15;

// Reduce quality
engine.adaptiveQuality = YES;
engine.autoScaleFPSThreshold = 20.0;

// Pause when screen locked
engine.pauseOnScreenLock = YES;
```

## Troubleshooting

### Wallpaper Not Appearing

**Check**: System Preferences → Security & Privacy → Accessibility
**Solution**: Grant ShaderCandy accessibility permissions

### High CPU Usage

**Check**: Frame rate and quality settings
**Solution**: Reduce target FPS to 15 or enable adaptive quality

### Display Artifacts

**Check**: GPU compatibility
**Solution**: Disable HDR or reduce shader complexity

## Advanced

### Custom Shader Paths

```objc
engine.customShaderPath = @"/path/to/shaders";
[engine scanForShaders];
```

### Automatic Rotation

```objc
// Rotate every 5 minutes
[spaceManager startAutoRotation:300.0];

// Or use specific shaders
NSArray *shaders = @[@"plasma", @"nebula", @"vortex"];
[spaceManager setRotationShaders:shaders interval:300.0];
```

## Uninstall

```bash
# Remove wallpaper
ShaderCandyPlayer.app/Contents/MacOS/ShaderCandyPlayer --clear-wallpaper

# Uninstall completely
./uninstall_macos.sh
```

## API Reference

### WallpaperEngine

```objc
@interface WallpaperEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)start;
- (void)stop;
- (BOOL)setWallpaperForAllDesktops:(NSString *)shaderName;
- (BOOL)setWallpaperForDesktop:(NSString *)desktopID withShader:(NSString *)shaderName;
@property(nonatomic, assign) NSInteger targetFPS;
@property(nonatomic, assign) BOOL pauseOnBattery;
@end
```
