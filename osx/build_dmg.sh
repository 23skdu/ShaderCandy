#!/bin/bash
#
# build_dmg.sh
# Complete build script for ShaderCandy DMG installer
# This script builds everything and creates a distribution-ready DMG
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
INSTALLER_DIR="$SCRIPT_DIR/installer"
RESOURCES_DIR="$SCRIPT_DIR/resources"
DMG_DIR="$SCRIPT_DIR/dmg"

echo "========================================"
echo "ShaderCandy DMG Builder"
echo "========================================"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Check for required tools
check_tools() {
    echo "Checking required tools..."
    
    local missing=()
    
    for cmd in cmake make xcodegen; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing tools: ${missing[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    log_info "All required tools available"
}

# Step 1: Build main project
build_main() {
    echo ""
    echo "Step 1/4: Building ShaderCandy..."
    echo "--------------------------------"
    
    cd "$PROJECT_ROOT"
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_TESTS=ON \
             -DBUILD_SCREENSAVER_MACOS=ON \
             -DBUILD_OPENGL=OFF
    
    make -j$(sysctl -n hw.ncpu)
    
    log_info "ShaderCandy built successfully"
}

# Step 2: Build installer app
build_installer() {
    echo ""
    echo "Step 2/4: Building Installer App..."
    echo "------------------------------------"
    
    cd "$INSTALLER_DIR"
    
    # Generate Xcode project
    xcodegen generate
    
    # Build the installer
    xcodebuild -project ShaderCandyInstaller.xcodeproj \
        -scheme ShaderCandyInstaller \
        -configuration Release \
        -derivedDataPath build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    # Copy built app to resources
    mkdir -p "$RESOURCES_DIR"
    cp -R "build/Build/Products/Release/ShaderCandy Installer.app" "$RESOURCES_DIR/"
    
    log_info "Installer app built successfully"
}

# Step 3: Create DMG
create_dmg() {
    echo ""
    echo "Step 3/4: Creating DMG..."
    echo "-------------------------"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf '$TEMP_DIR'" EXIT
    
    # Copy screensaver
    cp -R "$BUILD_DIR/ShaderCandy.saver" "$TEMP_DIR/"
    
    # Copy installer app
    cp -R "$RESOURCES_DIR/ShaderCandy Installer.app" "$TEMP_DIR/"
    
    # Create Applications symlink
    ln -sf /Applications "$TEMP_DIR/Applications"
    
    # Copy background image
    mkdir -p "$TEMP_DIR/.background"
    cp "$RESOURCES_DIR/background.png" "$TEMP_DIR/.background/"
    
    # Copy folder settings
    cp "$RESOURCES_DIR/BackgroundFolder.dsstore" "$TEMP_DIR/.DS_Store"
    
    # Create DMG
    mkdir -p "$DMG_DIR"
    DMG_NAME="ShaderCandy-Installer-$(date +%Y%m%d)"
    DMG_PATH="$DMG_DIR/$DMG_NAME.dmg"
    
    hdiutil create \
        -volname "ShaderCandy Installer" \
        -srcfolder "$TEMP_DIR" \
        -ov \
        -format UDZO \
        -imagekey zlib-level=9 \
        "$DMG_PATH"
    
    log_info "DMG created: $DMG_PATH"
}

# Step 4: Summary
show_summary() {
    echo ""
    echo "========================================"
    echo "Build Complete!"
    echo "========================================"
    echo ""
    
    if [ -f "$DMG_DIR"/*.dmg ]; then
        DMG_SIZE=$(du -h "$DMG_DIR"/*.dmg | cut -f1)
        echo "📦 DMG Location: $DMG_DIR/"
        echo "   Size: $DMG_SIZE"
        echo ""
        echo "Next steps for distribution:"
        echo ""
        echo "1. Sign the DMG (required for Gatekeeper):"
        echo '   codesign --force --deep --sign "Developer ID Application: Your Name" \'
        echo "   $DMG_DIR/*.dmg"
        echo ""
        echo "2. Notarize for Gatekeeper approval:"
        echo '   xcrun altool --notarize-app -f "$DMG_DIR/*.dmg" \'
        echo '   --apiKey API_KEY --apiIssuer ISSUER_ID'
        echo ""
        echo "3. Staple the notarization:"
        echo "   xcrun stapler staple $DMG_DIR/*.dmg"
        echo ""
    else
        log_error "DMG not found!"
        exit 1
    fi
}

# Main execution
main() {
    check_tools
    build_main
    build_installer
    create_dmg
    show_summary
}

main "$@"
