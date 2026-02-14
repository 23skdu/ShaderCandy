#!/bin/bash
# ShaderCandy macOS Installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=================================="
echo "ShaderCandy macOS Installer"
echo "=================================="
echo ""

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo "macOS Version: $MACOS_VERSION"

# Check for required tools
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check for Xcode Command Line Tools
    if ! command -v clang &> /dev/null; then
        echo "Error: Xcode Command Line Tools not found"
        echo "Please install with: xcode-select --install"
        exit 1
    fi
    
    # Check for cmake
    if ! command -v cmake &> /dev/null; then
        echo "CMake not found. Installing via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Please install Homebrew first:"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
        brew install cmake
    fi
    
    echo "Prerequisites OK!"
    echo ""
}

# Build project
build_project() {
    echo "Building ShaderCandy and Player..."
    
    cd "$PROJECT_ROOT"
    
    # Create build directory
    mkdir -p build
    cd build
    
    # Configure with CMake
    echo "Configuring build..."
    cmake .. -G Xcode \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
        -DBUILD_METAL=ON \
        -DBUILD_OPENGL=OFF \
        -DBUILD_SCREENSAVER_MACOS=ON \
        -DBUILD_STANDALONE_APP=ON
    
    # Build Screensaver
    echo "Compiling Screensaver..."
    xcodebuild -project ShaderCandy.xcodeproj \
               -scheme ShaderCandy \
               -configuration Release \
               -derivedDataPath ./DerivedData

    # Build Player
    echo "Compiling Player..."
    xcodebuild -project ShaderCandy.xcodeproj \
               -scheme ShaderCandyPlayer \
               -configuration Release \
               -derivedDataPath ./DerivedData
    
    echo "Build completed!"
    echo ""
}

# Explicitly set compiler to system clang to avoid CMake detection issues
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# Alternative build using make
build_with_make() {
    echo "Building ShaderCandy (CMake with Make)..."
    
    cd "$PROJECT_ROOT"
    
    mkdir -p build-make
    cd build-make
    
    cmake .. -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
        -DBUILD_METAL=ON \
        -DBUILD_OPENGL=OFF \
        -DBUILD_SCREENSAVER_MACOS=ON \
        -DBUILD_STANDALONE_APP=ON
    
    make -j$(sysctl -n hw.ncpu)
    
    echo "Build completed!"
    echo ""
}

# Install screensaver
install_screensaver() {
    echo "Installing ShaderCandy screensaver..."
    
    # Find built screensaver bundle - look in multiple possible locations
    SAVER_BUNDLE=""
    
    # Check CMake build directory (primary location for modern builds)
    if [ -d "$PROJECT_ROOT/build/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build/ShaderCandy.saver"
    # Check build-make directory (legacy Make builds)
    elif [ -d "$PROJECT_ROOT/build-make/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build-make/ShaderCandy.saver"
    # Check Xcode DerivedData (Xcode builds)
    elif [ -d "$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandy.saver"
    # Check Xcode build directory
    elif [ -d "$PROJECT_ROOT/build/Build/Products/Release/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build/Build/Products/Release/ShaderCandy.saver"
    else
        echo "Error: Could not find built screensaver bundle"
        echo "Searched in:"
        echo "  - $PROJECT_ROOT/build/ShaderCandy.saver"
        echo "  - $PROJECT_ROOT/build-make/ShaderCandy.saver"
        echo "  - $PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandy.saver"
        echo ""
        echo "Please build first with: ./install/install_macos.sh"
        exit 1
    fi
    
    echo "Found screensaver at: $SAVER_BUNDLE"
    
    # Install to user Library
    USER_SAVER_DIR="$HOME/Library/Screen Savers"
    mkdir -p "$USER_SAVER_DIR"
    
    # Remove old version if exists
    if [ -d "$USER_SAVER_DIR/ShaderCandy.saver" ]; then
        echo "Removing old version..."
        rm -rf "$USER_SAVER_DIR/ShaderCandy.saver"
    fi
    
    # Copy new version
    cp -R "$SAVER_BUNDLE" "$USER_SAVER_DIR/"
    
    echo "Screensaver installed to: $USER_SAVER_DIR/ShaderCandy.saver"
    echo ""
    
    # Alternative: Install system-wide (requires sudo)
    read -p "Install system-wide (requires sudo)? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SYSTEM_SAVER_DIR="/Library/Screen Savers"
        sudo rm -rf "$SYSTEM_SAVER_DIR/ShaderCandy.saver"
        sudo cp -R "$SAVER_BUNDLE" "$SYSTEM_SAVER_DIR/"
        echo "Screensaver installed system-wide!"
        echo ""
    fi
}

# Create standalone app bundle (Installing the one we built)
create_app_bundle() {
    read -p "Install standalone player app? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Find built app bundle
        APP_BUNDLE=""
        
        # Check CMake build directory
        if [ -d "$PROJECT_ROOT/build/ShaderCandyPlayer.app" ]; then
            APP_BUNDLE="$PROJECT_ROOT/build/ShaderCandyPlayer.app"
        # Check Make build directory
        elif [ -d "$PROJECT_ROOT/build-make/ShaderCandyPlayer.app" ]; then
            APP_BUNDLE="$PROJECT_ROOT/build-make/ShaderCandyPlayer.app"
        # Check Xcode DerivedData
        elif [ -d "$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandyPlayer.app" ]; then
            APP_BUNDLE="$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandyPlayer.app"
        # Check Xcode build directory
        elif [ -d "$PROJECT_ROOT/build/Build/Products/Release/ShaderCandyPlayer.app" ]; then
            APP_BUNDLE="$PROJECT_ROOT/build/Build/Products/Release/ShaderCandyPlayer.app"
        else
            echo "Error: Could not find built Player app bundle"
            echo "Please check build logs."
            return
        fi

        echo "Found player app at: $APP_BUNDLE"
        
        # Copy to Applications
        read -p "Copy to /Applications? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove existing
            if [ -d "/Applications/ShaderCandy Player.app" ]; then
                rm -rf "/Applications/ShaderCandy Player.app"
            fi
            
            cp -R "$APP_BUNDLE" "/Applications/"
            echo "App installed to /Applications/ShaderCandy Player.app"
            echo ""
        else
            echo "App bundle is located at: $APP_BUNDLE"
            echo "You can run it from there."
            echo ""
        fi
    fi
}

# Create LaunchAgent for auto-start
setup_launchagent() {
    read -p "Create LaunchAgent for auto-start at login? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LAUNCH_AGENTS_DIR"
        
        cat > "$LAUNCH_AGENTS_DIR/com.shadercandy.screensaver.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.shadercandy.screensaver</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
        
        echo "LaunchAgent created!"
        echo ""
    fi
}

# Open System Preferences
open_preferences() {
    read -p "Open System Preferences to configure screensaver? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open /System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane
    fi
}

# Uninstall screensaver
uninstall_screensaver() {
    echo "Uninstalling ShaderCandy..."
    
    # Remove user screensaver
    USER_SAVER_DIR="$HOME/Library/Screen Savers/ShaderCandy.saver"
    if [ -d "$USER_SAVER_DIR" ]; then
        echo "Removing user screensaver..."
        rm -rf "$USER_SAVER_DIR"
    fi
    
    # Remove system screensaver (requires sudo)
    SYSTEM_SAVER_DIR="/Library/Screen Savers/ShaderCandy.saver"
    if [ -d "$SYSTEM_SAVER_DIR" ]; then
        echo "Removing system screensaver (might require password)..."
        sudo rm -rf "$SYSTEM_SAVER_DIR"
    fi
    
    # Remove LaunchAgent
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.shadercandy.screensaver.plist"
    if [ -f "$LAUNCH_AGENT" ]; then
        echo "Removing LaunchAgent..."
        rm "$LAUNCH_AGENT"
    fi
    
    # Remove App Bundle from Applications
    # Remove both ShaderCandy.app and ShaderCandy Player.app just in case
    for app_name in "ShaderCandy.app" "ShaderCandy Player.app"; do
        APP_BUNDLE="/Applications/$app_name"
        if [ -d "$APP_BUNDLE" ]; then
            echo "Removing Application: $app_name..."
            rm -rf "$APP_BUNDLE"
        fi
    done

    # Remove build artifacts
    echo "Cleaning up build artifacts..."
    if [ -d "$PROJECT_ROOT/build" ]; then
        rm -rf "$PROJECT_ROOT/build"
    fi
    if [ -d "$PROJECT_ROOT/build-make" ]; then
        rm -rf "$PROJECT_ROOT/build-make"
    fi
    
    echo "Uninstallation complete!"
    echo ""
}

# Main installation process
main() {
    # Parse arguments
    SKIP_BUILD=false
    BUILD_METHOD="xcode"
    UNINSTALL=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --make)
                BUILD_METHOD="make"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --uninstall     Uninstall ShaderCandy"
                echo "  --skip-build    Skip building (install only)"
                echo "  --make          Build using Make instead of Xcode"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [ "$UNINSTALL" = true ]; then
        uninstall_screensaver
        exit 0
    fi
    
    # Run installation steps
    check_prerequisites
    
    if [ "$SKIP_BUILD" = false ]; then
        if [ "$BUILD_METHOD" = "xcode" ]; then
            build_project
        else
            build_with_make
        fi
    fi
    
    install_screensaver
    create_app_bundle
    setup_launchagent
    
    echo "=================================="
    echo "Installation Complete!"
    echo "=================================="
    echo ""
    echo "ShaderCandy has been installed to:"
    echo "  $HOME/Library/Screen Savers/ShaderCandy.saver"
    echo ""
    echo "To configure:"
    echo "  1. Open System Preferences"
    echo "  2. Go to Desktop & Screen Saver"
    echo "  3. Select ShaderCandy from the list"
    echo ""
    echo "Enjoy your eye-candy shaders!"
    echo ""
    
    open_preferences
}

# Run main function
main "$@"
