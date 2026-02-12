#!/bin/bash
#
# build_installer.sh
# Builds the DMG installer for ShaderCandy
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
INSTALLER_DIR="$PROJECT_ROOT/osx/installer"
DMG_DIR="$PROJECT_ROOT/osx/dmg"
RESOURCES_DIR="$PROJECT_ROOT/osx/resources"

echo "========================================"
echo "ShaderCandy Installer Builder"
echo "========================================"

# Step 1: Build main project
echo ""
echo "Step 1: Building ShaderCandy..."
cd "$PROJECT_ROOT"

if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

cd "$BUILD_DIR"
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF
make -j$(sysctl -n hw.ncpu)

echo "✅ ShaderCandy built successfully"

# Step 2: Build installer app
echo ""
echo "Step 2: Building Installer App..."

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
fi

cd "$INSTALLER_DIR"

# Generate Xcode project
xcodegen generate

# Build the installer app
xcodebuild -project ShaderCandyInstaller.xcodeproj \
    -scheme ShaderCandyInstaller \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Copy built app
mkdir -p "$RESOURCES_DIR"
cp -R "build/Build/Products/Release/ShaderCandy Installer.app" "$RESOURCES_DIR/"

echo "✅ Installer app built successfully"

# Step 3: Create DMG
echo ""
echo "Step 3: Creating DMG..."

# Create temporary directory for DMG
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

# Copy screensaver
cp -R "$BUILD_DIR/ShaderCandy.saver" "$TEMP_DIR/"

# Copy installer app
cp -R "$RESOURCES_DIR/ShaderCandy Installer.app" "$TEMP_DIR/"

# Create Applications symlink
ln -sf /Applications "$TEMP_DIR/Applications"

# Copy background
mkdir -p "$TEMP_DIR/.background"
cp "$RESOURCES_DIR/background.png" "$TEMP_DIR/.background/"

# Create background folder settings
cp "$RESOURCES_DIR/BackgroundFolder.dsstore" "$TEMP_DIR/.DS_Store"

# Create DMG
DMG_NAME="ShaderCandy-Installer-$(date +%Y%m%d)"
DMG_PATH="$DMG_DIR/$DMG_NAME.dmg"

mkdir -p "$DMG_DIR"

hdiutil create \
    -volname "ShaderCandy Installer" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo "✅ DMG created successfully!"
    echo "   Size: $DMG_SIZE"
    echo "   Location: $DMG_PATH"
else
    echo "❌ Failed to create DMG"
    exit 1
fi

echo ""
echo "========================================"
echo "Build Complete!"
echo "========================================"
echo ""
echo "DMG location: $DMG_PATH"
echo ""
echo "Next steps for distribution:"
echo "  1. Sign the DMG:"
echo "     codesign --force --deep --sign 'Developer ID' '$DMG_PATH'"
echo ""
echo "  2. Notarize for Gatekeeper:"
echo "     xcrun altool --notarize-app -f '$DMG_PATH' --apiKey KEY --apiIssuer ID"
echo ""
echo "  3. Staple the notarization:"
echo "     xcrun stapler staple '$DMG_PATH'"
echo ""
