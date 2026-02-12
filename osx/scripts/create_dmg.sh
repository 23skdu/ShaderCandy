#!/bin/bash
#
# create_dmg.sh
# Creates a DMG installer for ShaderCandy
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
DMG_DIR="$PROJECT_ROOT/osx/dmg"
APP_NAME="ShaderCandy"
INSTALLER_NAME="ShaderCandy Installer"

echo "========================================"
echo "ShaderCandy DMG Creator"
echo "========================================"

# Check for required tools
if ! command -v hdiutil &> /dev/null; then
    echo "Error: hdiutil not found. This requires macOS."
    exit 1
fi

# Clean up old DMG
echo "Cleaning up old files..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Create temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

echo "Preparing DMG contents..."

# Copy installer app
cp -R "$BUILD_DIR/ShaderCandy.saver" "$TEMP_DIR/"
cp -R "$PROJECT_ROOT/osx/installer/build/ShaderCandy Installer.app" "$TEMP_DIR/" 2>/dev/null || {
    echo "Note: Building installer app..."
}

# Create Applications symlink
ln -sf /Applications "$TEMP_DIR/Applications"

# Copy background image
mkdir -p "$TEMP_DIR/.background"
cp "$PROJECT_ROOT/osx/resources/background.png" "$TEMP_DIR/.background/"

# Create DMG
DMG_NAME="${APP_NAME}-Installer-$(date +%Y%m%d)"
DMG_PATH="$DMG_DIR/$DMG_NAME.dmg"

echo "Creating DMG image..."
hdiutil create \
    -volname "$INSTALLER_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Verify DMG
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
echo "DMG Ready for Distribution!"
echo "========================================"
echo ""
echo "To distribute:"
echo "  1. Sign the DMG (if distributing outside App Store):"
echo "     codesign --force --deep --sign \"Developer ID\" \"$DMG_PATH\""
echo ""
echo "  2. Notarize for Gatekeeper approval:"
echo "     xcrun altool --notarize-app -f \"$DMG_PATH\" --apiKey API_KEY --apiIssuer ISSUER_ID"
echo ""
echo "  3. Staple the notarization:"
echo "     xcrun stapler staple \"$DMG_PATH\""
echo ""
