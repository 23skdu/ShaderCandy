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
    echo "Building ShaderCandy..."
    
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
        -DBUILD_SCREENSAVER_MACOS=ON
    
    # Build
    echo "Compiling..."
    xcodebuild -project ShaderCandy.xcodeproj \
               -scheme ShaderCandy \
               -configuration Release \
               -derivedDataPath ./DerivedData
    
    echo "Build completed!"
    echo ""
}

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
        -DBUILD_SCREENSAVER_MACOS=ON
    
    make -j$(sysctl -n hw.ncpu)
    
    echo "Build completed!"
    echo ""
}

# Install screensaver
install_screensaver() {
    echo "Installing ShaderCandy screensaver..."
    
    # Find built screensaver bundle
    SAVER_BUNDLE=""
    if [ -d "$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build/DerivedData/Build/Products/Release/ShaderCandy.saver"
    elif [ -d "$PROJECT_ROOT/build-make/ShaderCandy.saver" ]; then
        SAVER_BUNDLE="$PROJECT_ROOT/build-make/ShaderCandy.saver"
    else
        echo "Error: Could not find built screensaver bundle"
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

# Create standalone app bundle
create_app_bundle() {
    read -p "Create standalone app bundle? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        APP_DIR="$PROJECT_ROOT/build/ShaderCandy.app"
        
        mkdir -p "$APP_DIR/Contents/MacOS"
        mkdir -p "$APP_DIR/Contents/Resources"
        
        # Create Info.plist
        cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ShaderCandy</string>
    <key>CFBundleIdentifier</key>
    <string>com.shadercandy.app</string>
    <key>CFBundleName</key>
    <string>ShaderCandy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
        
        # Create launcher script
        cat > "$APP_DIR/Contents/MacOS/ShaderCandy" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/../Resources"
exec "$DIR/shadercandy-bin"
EOF
        chmod +x "$APP_DIR/Contents/MacOS/ShaderCandy"
        
        echo "App bundle created at: $APP_DIR"
        echo ""
        
        # Copy to Applications
        read -p "Copy to /Applications? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp -R "$APP_DIR" "/Applications/"
            echo "App installed to /Applications!"
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

# Main installation process
main() {
    # Parse arguments
    SKIP_BUILD=false
    BUILD_METHOD="xcode"
    
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
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
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
