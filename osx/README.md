# ShaderCandy macOS DMG Installer

This directory contains the tools to create a professional macOS DMG installer for ShaderCandy.

## Contents

```
osx/
├── installer/           # SwiftUI installer application
│   ├── MainInstallerView.swift
│   ├── ShaderCandyInstaller.swift
│   ├── Info.plist
│   └── project.yml      # XcodeGen configuration
├── scripts/
│   ├── create_dmg.sh   # Create DMG from pre-built components
│   └── build_installer.sh  # Full build process
├── resources/
│   ├── background.png   # DMG background image
│   └── BackgroundFolder.dsstore
└── README.md
```

## Quick Start

### Option 1: Full Build (Recommended)

```bash
cd osx
chmod +x build_installer.sh
./build_installer.sh
```

This will:
1. Build the ShaderCandy screensaver
2. Build the GUI installer app
3. Create the DMG file

### Option 2: Create DMG Only

If you already have a built screensaver:

```bash
cd osx/scripts
./create_dmg.sh
```

## Installation Options

The DMG includes a GUI installer with:

- **Install Location**: User (`~/Library/Screen Savers/`) or System-wide (`/Library/Screen Savers/`)
- **Desktop Shortcut**: Create an alias on the desktop
- **LaunchAgent**: Auto-start screensaver at login
- **Open Preferences**: Launch System Preferences after installation

## Distribution

### Signing

For distribution outside the App Store:

```bash
# Sign the DMG
codesign --force --deep --sign "Developer ID Application: Your Name" ShaderCandy-Installer-*.dmg
```

### Notarization

Apple requires notarization for Gatekeeper approval:

```bash
# Upload for notarization
xcrun altool --notarize-app \
    -f ShaderCandy-Installer-*.dmg \
    --apiKey API_KEY \
    --apiIssuer ISSUER_ID

# Check status (repeat until approved)
xcrun altool --notarization-info REQUEST_UUID --apiKey API_KEY --apiIssuer ISSUER_ID

# Staple the notarization
xcrun stapler staple ShaderCandy-Installer-*.dmg
```

## DMG Structure

```
ShaderCandy Installer.dmg/
├── .background/
│   └── background.png
├── Applications -> /Applications
├── ShaderCandy.saver/
└── ShaderCandy Installer.app/
```

## Requirements

- macOS 11.0 (Big Sur) or later
- Xcode 13+ (for building)
- XcodeGen (for Xcode project generation)
  - Install via: `brew install xcodegen`

## Customization

### Background Image

Replace `resources/background.png` with your own branded image (recommended: 1920x1080 PNG).

### App Icon

The installer app uses SF Symbols. To customize, modify the `Image()` calls in `MainInstallerView.swift`.

## Troubleshooting

### "Developer cannot be verified" warning

This occurs if the DMG is not notariled. See the Notarization section above.

### Installation fails with permission error

The system-wide installation requires administrator privileges. Try the user installation instead.

### Installer app won't launch

Ensure you're running macOS 11.0 or later. The installer requires SwiftUI.
