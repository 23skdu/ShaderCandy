#!/bin/bash
#
# ShaderCandy DMG Creator
# Creates a DMG installer for ShaderCandy on macOS
#
# Usage: ./scripts/create_dmg.sh [OPTIONS]
#
# Options:
#   --skip-build       Skip building, use existing build artifacts
#   --make             Build using Make instead of Xcode
#   --volume-name      Custom DMG volume name (default: ShaderCandy)
#   --output           Custom output path for DMG
#   --help, -h         Show this help message
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default settings
VOLUME_NAME="ShaderCandy"
OUTPUT_PATH=""
BUILD_METHOD="xcode"
SKIP_BUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for Xcode Command Line Tools
    if ! command -v clang &> /dev/null; then
        log_error "Xcode Command Line Tools not found"
        echo "Please install with: xcode-select --install"
        exit 1
    fi
    
    # Check for cmake
    if ! command -v cmake &> /dev/null; then
        log_error "CMake not found"
        echo "Please install CMake via Homebrew: brew install cmake"
        exit 1
    fi
    
    # Check for hdiutil (required for DMG creation)
    if ! command -v hdiutil &> /dev/null; then
        log_error "hdiutil not found - this is a macOS system tool"
        exit 1
    fi
    
    log_success "Prerequisites OK!"
    echo ""
}

# Build the project
build_project() {
    log_info "Building ShaderCandy..."
    
    cd "$PROJECT_ROOT"
    
    # Create build directory
    mkdir -p build
    cd build
    
    # Configure with CMake using Make generator
    log_info "Configuring build with CMake..."
    cmake .. -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
        -DBUILD_METAL=ON \
        -DBUILD_OPENGL=OFF \
        -DBUILD_SCREENSAVER_MACOS=ON \
        -DBUILD_STANDALONE_APP=ON
    
    # Build
    log_info "Compiling..."
    make -j$(sysctl -n hw.ncpu)
    
    log_success "Build completed!"
    echo ""
}

# Build using Xcode
build_with_xcode() {
    log_info "Building ShaderCandy with Xcode..."
    
    cd "$PROJECT_ROOT"
    
    # Create build directory
    mkdir -p build
    cd build
    
    # Configure with CMake using Xcode generator
    log_info "Configuring build with CMake (Xcode)..."
    cmake .. -G Xcode \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
        -DBUILD_METAL=ON \
        -DBUILD_OPENGL=OFF \
        -DBUILD_SCREENSAVER_MACOS=ON \
        -DBUILD_STANDALONE_APP=ON
    
    # Build Screensaver
    log_info "Compiling Screensaver..."
    xcodebuild -project ShaderCandy.xcodeproj \
               -scheme ShaderCandy \
               -configuration Release \
               -derivedDataPath ./DerivedData
    
    # Build Player
    log_info "Compiling Player..."
    xcodebuild -project ShaderCandy.xcodeproj \
               -scheme ShaderCandyPlayer \
               -configuration Release \
               -derivedDataPath ./DerivedData
    
    log_success "Build completed!"
    echo ""
}

# Find built bundles
find_bundles() {
    log_info "Locating built bundles..."
    
    SAVER_BUNDLE=""
    APP_BUNDLE=""
    
    # Check CMake build directory
    if [ -d "$PROJECT_ROOT/build/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build/ShaderCandy.saver"
    elif [ -d "$PROJECT_ROOT/build/Build/Products/Release/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build/Build/Products/Release/ShaderCandy.saver"
    elif [ -d "$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandy.saver"
    fi
    
    # Check for Player app
    if [ -d "$PROJECT_ROOT/build/ShaderCandyPlayer.app" ]; then
        APP_BUNDLE="$PROJECT_ROOT/build/ShaderCandyPlayer.app"
    elif [ -d "$PROJECT_ROOT/build/Build/Products/Release/ShaderCandyPlayer.app" ]; then
        APP_BUNDLE="$PROJECT_ROOT/build/Build/Products/Release/ShaderCandyPlayer.app"
    elif [ -d "$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandyPlayer.app" ]; then
        APP_BUNDLE="$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandyPlayer.app"
    fi
    
    # Check build-make directory
    if [ -z "$SAVER_BUNDLE" ] && [ -d "$PROJECT_ROOT/build-make/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build-make/ShaderCandy.saver"
    fi
    if [ -z "$APP_BUNDLE" ] && [ -d "$PROJECT_ROOT/build-make/ShaderCandyPlayer.app" ]; then
        APP_BUNDLE="$PROJECT_ROOT/build-make/ShaderCandyPlayer.app"
    fi
    
    if [ -z "$SAVER_BUNDLE" ]; then
        log_error "Could not find ShaderCandy.saver bundle"
        log_error "Please build first with: ./install/install_macos.sh or use --skip-build false"
        exit 1
    fi
    
    if [ -z "$APP_BUNDLE" ]; then
        log_error "Could not find ShaderCandyPlayer.app bundle"
        log_error "Please build first with: ./install/install_macos.sh or use --skip-build false"
        exit 1
    fi
    
    log_success "Found screensaver: $SAVER_BUNDLE"
    log_success "Found player app: $APP_BUNDLE"
    echo ""
}

# Create the DMG
create_dmg() {
    log_info "Creating DMG installer..."
    
    # Create temporary staging directory
    STAGING_DIR=$(mktemp -d)
    DMG_FINAL="${OUTPUT_PATH:-$PROJECT_ROOT/ShaderCandy-${VOLUME_NAME}.dmg}"
    
    # Clean up function
    cleanup() {
        log_info "Cleaning up..."
        # Detach any mounted DMGs
        hdiutil detach "/Volumes/$VOLUME_NAME" 2>/dev/null || true
        if [ -d "$STAGING_DIR" ]; then
            rm -rf "$STAGING_DIR"
        fi
    }
    
    trap cleanup EXIT
    
    # Copy bundles to staging
    log_info "Copying bundles to staging area..."
    
    # Create staging structure with Applications symlink
    mkdir -p "$STAGING_DIR/Applications"
    ln -sf /Applications "$STAGING_DIR/Applications"
    
    # Copy screensaver
    cp -R "$SAVER_BUNDLE" "$STAGING_DIR/"
    
    # Copy player app
    cp -R "$APP_BUNDLE" "$STAGING_DIR/"
    
    log_info "Staging size: $(du -sh "$STAGING_DIR" | cut -f1)"
    
    # Use makehybrid to create DMG directly from folder
    log_info "Creating DMG from staging folder..."
    hdiutil makehybrid -hfs -hfs-volume-name "$VOLUME_NAME" \
        -ov -o "$DMG_FINAL" "$STAGING_DIR"
    
    # Compress the DMG
    log_info "Compressing DMG..."
    DMG_TEMP="${DMG_FINAL}.temp.dmg"
    mv "$DMG_FINAL" "$DMG_TEMP"
    hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_FINAL"
    rm -f "$DMG_TEMP"
    
    # Set permissions
    chmod 644 "$DMG_FINAL"
    
    log_success "DMG created successfully!"
    log_success "Output: $DMG_FINAL"
    echo ""
    
    # Print file size
    FINAL_SIZE=$(ls -lh "$DMG_FINAL" | awk '{print $5}')
    log_info "Final DMG size: $FINAL_SIZE"
    echo ""
    
    # Offer to open in Finder
    if command -v Finder &> /dev/null; then
        read -p "Open DMG in Finder? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open -R "$DMG_FINAL"
        fi
    fi
}

# Main function
main() {
    echo "======================================"
    echo "  ShaderCandy DMG Creator"
    echo "======================================"
    echo ""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --make)
                BUILD_METHOD="make"
                shift
                ;;
            --volume-name)
                VOLUME_NAME="$2"
                shift 2
                ;;
            --output)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-build       Skip building, use existing build artifacts"
                echo "  --make             Build using Make instead of Xcode"
                echo "  --volume-name      Custom DMG volume name (default: ShaderCandy)"
                echo "  --output           Custom output path for DMG"
                echo "  --help, -h         Show this help message"
                echo ""
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Run installation steps
    check_prerequisites
    
    if [ "$SKIP_BUILD" = false ]; then
    if [ "$BUILD_METHOD" = "xcode" ]; then
        export CC=/usr/bin/clang
        export CXX=/usr/bin/clang++
        
        cd "$PROJECT_ROOT"
        
        # Clean previous build if it exists with different generator
        if [ -d "build" ] && grep -q "CMAKE_GENERATOR" build/CMakeCache.txt 2>/dev/null; then
            if ! grep -q "Unix Makefiles" build/CMakeCache.txt 2>/dev/null; then
                log_info "Removing incompatible build directory..."
                rm -rf build
            fi
        fi
        
        mkdir -p build
        cd build
        
        log_info "Configuring build with CMake..."
        cmake .. -G "Unix Makefiles" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
            -DBUILD_METAL=ON \
            -DBUILD_OPENGL=OFF \
            -DBUILD_SCREENSAVER_MACOS=ON \
            -DBUILD_STANDALONE_APP=ON \
            -DCMAKE_C_COMPILER=/usr/bin/clang \
            -DCMAKE_CXX_COMPILER=/usr/bin/clang++
        
        log_info "Compiling..."
        make -j$(sysctl -n hw.ncpu)
    else
        build_project
    fi
    fi
    
    find_bundles
    create_dmg
    
    echo "======================================"
    echo "  DMG Creation Complete!"
    echo "======================================"
    echo ""
    echo "The DMG installer has been created with:"
    echo "  - ShaderCandy.saver (screensaver)"
    echo "  - ShaderCandy Player.app (standalone player)"
    echo "  - Applications folder (for easy installation)"
    echo ""
    echo "To install:"
    echo "  1. Open the DMG file"
    echo "  2. Drag ShaderCandy.saver to the Screen Savers folder"
    echo "  3. Or drag ShaderCandy Player.app to Applications"
    echo ""
}

# Run main function
main "$@"
