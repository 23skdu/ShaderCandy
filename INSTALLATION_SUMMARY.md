# ShaderCandy Installation Summary

## Installation Location
- **Binary**: `~/.local/bin/shadercandy-screensaver`
- **Launcher**: `~/.local/bin/shadercandy-launcher`
- **Shaders**: `~/.local/share/shadercandy/shaders/` (69 shaders installed)
- **KDE Screensaver**: `~/.local/share/kscreensavers/shadercandy.desktop`
- **Wallpaper Plugin**: `~/.local/share/plasma/wallpapers/shadercandy/`

## Configuration Files

### XScreenSaver (`~/.xscreensaver`)
- Timeout: 5 minutes
- Auto-lock enabled
- ShaderCandy configured as the only screensaver

### KDE Screen Locker (`~/.config/kscreenlockerrc`)
- Autolock: Enabled
- Lock on Resume: Enabled
- Timeout: 300 seconds (5 minutes)
- Wallpaper Plugin: shadercandy

### Systemd Service (`~/.config/systemd/user/xscreensaver.service`)
- Auto-starts XScreenSaver with graphical session

## Usage

### Manual Launch
```bash
# Run directly
~/.local/bin/shadercandy-screensaver

# Run with specific shader
~/.local/bin/shadercandy-screensaver -shader nebula

# Run in window (for testing)
~/.local/bin/shadercandy-screensaver -window-id <window_id>
```

### Enable/Disable Service
```bash
# Enable xscreensaver service
systemctl --user enable xscreensaver.service
systemctl --user start xscreensaver.service

# Disable
systemctl --user stop xscreensaver.service
systemctl --user disable xscreensaver.service
```

### KDE Settings
1. Open System Settings > Workspace Behavior > Screen Locking
2. Ensure "Lock screen automatically" is checked
3. Set timeout to 5 minutes
4. The ShaderCandy wallpaper is already configured as the lock screen background

## Controls (when screensaver is running)
- **Right Arrow**: Next shader
- **ESC or Q**: Exit screensaver
- **Mouse Click**: Exit screensaver

## Troubleshooting

### Black Screen
- Verify OpenGL 3.3+ support: `glxinfo | grep "OpenGL version"`
- Check shader files exist: `ls ~/.local/share/shadercandy/shaders/`

### XScreenSaver not starting
- Check service status: `systemctl --user status xscreensaver`
- Manual start: `/usr/bin/xscreensaver -nosplash`

### KDE not using ShaderCandy
- Verify wallpaper plugin: `ls ~/.local/share/plasma/wallpapers/shadercandy/`
- Check KDE config: `cat ~/.config/kscreenlockerrc`

## Uninstall
```bash
# Remove binaries
rm ~/.local/bin/shadercandy-screensaver
rm ~/.local/bin/shadercandy-launcher

# Remove shaders
rm -rf ~/.local/share/shadercandy

# Remove KDE integration
rm ~/.local/share/kscreensavers/shadercandy.desktop
rm -rf ~/.local/share/plasma/wallpapers/shadercandy

# Remove config
rm ~/.xscreensaver

# Stop service
systemctl --user stop xscreensaver
rm ~/.config/systemd/user/xscreensaver.service
```
