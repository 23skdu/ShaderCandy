#!/bin/bash
# ShaderCandy Linux Installer
# Supports: Ubuntu/Debian, Fedora/RHEL, Arch Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=================================="
echo "ShaderCandy Linux Installer"
echo "=================================="
echo ""

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    DISTRO_VERSION=$VERSION_ID
else
    echo "Error: Cannot detect Linux distribution"
    exit 1
fi

echo "Detected: $NAME $VERSION_ID"
echo ""

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Note: Some operations may require sudo privileges"
    echo ""
fi

# Install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                cmake \
                ninja-build \
                git \
                libgl1-mesa-dev \
                libglx-dev \
                libx11-dev \
                libxss-dev \
                libxxf86vm-dev \
                libxi-dev \
                libxrandr-dev \
                mesa-common-dev \
                xscreensaver \
                xscreensaver-data
            ;;
            
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf install -y \
                gcc-c++ \
                cmake \
                ninja-build \
                git \
                mesa-libGL-devel \
                mesa-libGLU-devel \
                libX11-devel \
                libXScrnSaver-devel \
                libXxf86vm-devel \
                libXi-devel \
                libXrandr-devel \
                xscreensaver \
                xscreensaver-base
            ;;
            
        arch|manjaro|endeavouros)
            sudo pacman -S --needed --noconfirm \
                base-devel \
                cmake \
                ninja \
                git \
                mesa \
                libx11 \
                libxss \
                libxxf86vm \
                libxi \
                libxrandr \
                xscreensaver
            ;;
            
        opensuse*|suse*)
            sudo zypper install -y \
                gcc-c++ \
                cmake \
                ninja \
                git \
                Mesa-libGL-devel \
                libX11-devel \
                libXss-devel \
                libXxf86vm-devel \
                libXi-devel \
                libXrandr-devel \
                xscreensaver
            ;;
            
        *)
            echo "Warning: Distribution '$DISTRO' not officially supported"
            echo "Please install the following packages manually:"
            echo "  - build tools (gcc, g++, make, cmake)"
            echo "  - OpenGL development libraries (Mesa)"
            echo "  - X11 development libraries (libX11, libXss)"
            echo ""
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
    
    echo "Dependencies installed successfully!"
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
    cmake .. -GNinja -DCMAKE_BUILD_TYPE=Release
    
    # Build
    echo "Compiling..."
    ninja -j$(nproc)
    
    echo "Build completed!"
    echo ""
}

# Install binaries
install_binaries() {
    echo "Installing ShaderCandy..."
    
    cd "$PROJECT_ROOT/build"
    
    # Install binary
    sudo install -m 755 shadercandy-screensaver /usr/local/bin/
    
    # Install shaders
    sudo mkdir -p /usr/local/share/shadercandy/shaders
    sudo cp ../shaders/*.frag /usr/local/share/shadercandy/shaders/ 2>/dev/null || true
    sudo cp ../shaders/effects/*.frag /usr/local/share/shadercandy/shaders/ 2>/dev/null || true
    sudo cp -r ../shaders/base /usr/local/share/shadercandy/shaders/ 2>/dev/null || true
    
    # Set permissions
    sudo chmod -R 755 /usr/local/share/shadercandy
    
    echo "Binaries installed to /usr/local/bin/"
    echo "Shaders installed to /usr/local/share/shadercandy/shaders/"
    echo ""
}

# Configure KDE Plasma Screen Saver
configure_kde_screensaver() {
    echo "Configuring KDE Plasma Screen Saver..."
    
    # KDE uses ScreenLocker which can use XScreenSaver
    # Check if kscreensaver or xscreensaver is available
    if command -v xscreensaver-command &> /dev/null; then
        # Configure for XScreenSaver (works on KDE)
        configure_xscreensaver
        
        echo "KDE is using XScreenSaver backend."
        echo "To enable ShaderCandy in KDE:"
        echo "  1. Open System Settings > Screen Saver"
        echo "  2. Select 'ShaderCandy' from the list"
        echo "  3. Click Apply"
        echo ""
        echo "Alternatively, run: kscreensaver -configure"
        echo ""
    else
        echo "Warning: XScreenSaver not found. KDE Screen Saver configuration skipped."
        echo "For KDE Plasma 5/6, please install xscreensaver:"
        echo "  Ubuntu/Debian: sudo apt install xscreensaver"
        echo "  Fedora:        sudo dnf install xscreensaver"
        echo "  Arch:          sudo pacman -S xscreensaver"
        echo ""
    fi
    
    # Create a simple script to launch in fullscreen for KDE
    KDE_SCRIPT_DIR="$HOME/.local/bin"
    mkdir -p "$KDE_SCRIPT_DIR"
    
    cat > "$KDE_SCRIPT_DIR/shadercandy-kde.sh" << 'KDEEOF'
#!/bin/bash
# ShaderCandy launcher for KDE Plasma
# Usage: Run this to start ShaderCandy in fullscreen mode

SCREENSAVER_BIN="/usr/local/bin/shadercandy-screensaver"

if [ ! -f "$SCREENSAVER_BIN" ]; then
    SCREENSAVER_BIN="$HOME/.local/bin/shadercandy-screensaver"
fi

if [ ! -f "$SCREENSAVER_BIN" ]; then
    echo "Error: shadercandy-screensaver not found!"
    exit 1
fi

# Find the active display
DISPLAY_NUM=$(echo $DISPLAY | cut -d':' -f2 | cut -d'.' -f1)
if [ -z "$DISPLAY_NUM" ]; then
    DISPLAY_NUM="0"
fi

# Get screen resolution
SCREEN_WIDTH=$(xrandr | grep -A1 "^Screen" | grep -oP '\d+(?= x)')
SCREEN_HEIGHT=$(xrandr | grep -A1 "^Screen" | grep -oP '(?<=x )\d+')

if [ -z "$SCREEN_WIDTH" ]; then
    SCREEN_WIDTH=1920
    SCREEN_HEIGHT=1080
fi

# Create a borderless fullscreen window
exec "$SCREENSAVER_BIN" -window-id 0x0
KDEEOF
    
    chmod +x "$KDE_SCRIPT_DIR/shadercandy-kde.sh"
    echo "Created KDE launcher: $KDE_SCRIPT_DIR/shadercandy-kde.sh"
    echo ""
}

# Configure XScreenSaver
configure_xscreensaver() {
    echo "Configuring XScreenSaver..."
    
    XSCREENSAVER_CONF="$HOME/.xscreensaver"
    
    # Backup existing config
    if [ -f "$XSCREENSAVER_CONF" ]; then
        cp "$XSCREENSAVER_CONF" "$XSCREENSAVER_CONF.backup.$(date +%Y%m%d%H%M%S)"
    fi
    
    # Check if already configured
    if [ -f "$XSCREENSAVER_CONF" ] && grep -q "shadercandy" "$XSCREENSAVER_CONF"; then
        echo "XScreenSaver already configured for ShaderCandy"
        return
    fi
    
    # Create or update config
    if [ ! -f "$XSCREENSAVER_CONF" ]; then
        # Create new config
        cat > "$XSCREENSAVER_CONF" << 'EOF'
timeout:        0
cycle:          0
lock:           False
lockTimeout:    0
fade:           True
fadeSeconds:    0.3
mode:           one
selected:       0
programs:                       \
  shadercandy                 \\n\t/usr/local/bin/shadercandy-screensaver    -root    \n\\t\n\\t\n\\t\n\\t\n
EOF
    else
        # Add to existing config
        # Find programs section and add shadercandy
        if grep -q "^programs:" "$XSCREENSAVER_CONF"; then
            # Insert after programs line
            sed -i '/^programs:/a\  shadercandy               \\\
\\t/usr/local/bin/shadercandy-screensaver    -root    \\\n\\t\\\n\\t\\\n\\t\\\n\\t\\\n' "$XSCREENSAVER_CONF"
        else
            # Add programs section
            cat >> "$XSCREENSAVER_CONF" << 'EOF'

programs:                       \
  shadercandy                 \
	/usr/local/bin/shadercandy-screensaver    -root    \
	\n	\n	\n	\
EOF
        fi
    fi
    
    echo "XScreenSaver configured!"
    echo ""
}

# Create systemd user service (optional)
setup_systemd_service() {
    read -p "Create systemd user service for auto-start? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SYSTEMD_DIR="$HOME/.config/systemd/user"
        mkdir -p "$SYSTEMD_DIR"
        
        cat > "$SYSTEMD_DIR/shadercandy.service" << 'EOF'
[Unit]
Description=ShaderCandy Screensaver
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/shadercandy-screensaver
Restart=always
RestartSec=10

[Install]
WantedBy=graphical-session.target
EOF
        
        systemctl --user daemon-reload
        systemctl --user enable shadercandy.service
        
        echo "Systemd service created and enabled"
        echo "Start with: systemctl --user start shadercandy"
        echo ""
    fi
}

# Create desktop entry
create_desktop_entry() {
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    
    cat > "$DESKTOP_DIR/shadercandy.desktop" << 'EOF'
[Desktop Entry]
Name=ShaderCandy
Comment=Eye-candy shader screensaver
Exec=/usr/local/bin/shadercandy-screensaver
Type=Application
Terminal=false
Categories=Screensaver;Graphics;
EOF
    
    # Also create for KDE screen saver (support both Plasma 5 and 6)
    for kde_dir in "$HOME/.kde/share/apps/kscreensavers" "$HOME/.local/share/kscreensavers"; do
        mkdir -p "$kde_dir"
        cat > "$kde_dir/shadercandy.desktop" << 'KDEEOF'
[Desktop Entry]
Name=ShaderCandy
Comment=Eye-candy shader screensaver
Exec=/usr/local/bin/shadercandy-screensaver -root
TryExec=/usr/local/bin/shadercandy-screensaver
Icon=video-display
Type=Screensaver
Categories=Qt;KDE;Graphics;ScreenSavers;
X-KDE-ScreensaverGroup=Abstract
X-KDE-SortingWeight=50
KDEEOF
    done
    
    echo "Desktop entry created"
    echo "KDE screensaver entry created"
    echo ""
}

# Uninstall ShaderCandy
uninstall_shadercandy() {
    echo "=================================="
    echo "ShaderCandy Uninstaller"
    echo "=================================="
    echo ""
    
    read -p "Are you sure you want to uninstall ShaderCandy? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
    
    echo "Removing ShaderCandy..."
    echo ""
    
    # Remove binary
    if [ -f "/usr/local/bin/shadercandy-screensaver" ]; then
        echo "Removing binary..."
        sudo rm -f /usr/local/bin/shadercandy-screensaver
    fi
    
    # Remove shaders
    if [ -d "/usr/local/share/shadercandy" ]; then
        echo "Removing shaders..."
        sudo rm -rf /usr/local/share/shadercandy
    fi
    
    # Remove XScreenSaver configuration
    XSCREENSAVER_CONF="$HOME/.xscreensaver"
    if [ -f "$XSCREENSAVER_CONF" ] && grep -q "shadercandy" "$XSCREENSAVER_CONF"; then
        echo "Removing XScreenSaver configuration..."
        # Backup before modifying
        cp "$XSCREENSAVER_CONF" "$XSCREENSAVER_CONF.backup.$(date +%Y%m%d%H%M%S)"
        # Remove shadercandy lines from programs section
        sed -i '/shadercandy/d' "$XSCREENSAVER_CONF"
    fi
    
    # Remove systemd service
    SYSTEMD_SERVICE="$HOME/.config/systemd/user/shadercandy.service"
    if [ -f "$SYSTEMD_SERVICE" ]; then
        echo "Removing systemd service..."
        systemctl --user stop shadercandy.service 2>/dev/null || true
        systemctl --user disable shadercandy.service 2>/dev/null || true
        rm -f "$SYSTEMD_SERVICE"
        systemctl --user daemon-reload
    fi
    
    # Remove desktop entry
    DESKTOP_ENTRY="$HOME/.local/share/applications/shadercandy.desktop"
    if [ -f "$DESKTOP_ENTRY" ]; then
        echo "Removing desktop entry..."
        rm -f "$DESKTOP_ENTRY"
    fi
    
    # Ask about build directory
    BUILD_DIR="$PROJECT_ROOT/build"
    if [ -d "$BUILD_DIR" ]; then
        read -p "Remove build directory? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing build directory..."
            rm -rf "$BUILD_DIR"
        fi
    fi
    
    echo ""
    echo "=================================="
    echo "Uninstall Complete!"
    echo "=================================="
    echo ""
    echo "ShaderCandy has been removed from your system."
    echo "Note: Dependencies installed by this script were not removed."
    echo ""
    exit 0
}

# Main installation process
main() {
    # Parse arguments
    SKIP_DEPS=false
    SKIP_BUILD=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --uninstall)
                uninstall_shadercandy
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-deps     Skip dependency installation"
                echo "  --skip-build    Skip building (install only)"
                echo "  --uninstall     Remove ShaderCandy from system"
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
    if [ "$SKIP_DEPS" = false ]; then
        install_dependencies
    fi
    
    if [ "$SKIP_BUILD" = false ]; then
        build_project
    fi
    
    install_binaries
    configure_kde_screensaver
    create_desktop_entry
    setup_systemd_service
    
    echo "=================================="
    echo "Installation Complete!"
    echo "=================================="
    echo ""
    echo "Usage:"
    echo "  Run directly: /usr/local/bin/shadercandy-screensaver"
    echo "  Test mode:    /usr/local/bin/shadercandy-screensaver -window-id <window_id>"
    echo "  KDE mode:     ~/.local/bin/shadercandy-kde.sh"
    echo ""
    echo "For KDE Plasma:"
    echo "  1. Open System Settings > Screen Saver"
    echo "  2. Select 'ShaderCandy' from the list"
    echo "  Or run: kscreensaver -configure"
    echo ""
    echo "Uninstall:"
    echo "  Run: $0 --uninstall"
    echo ""
    echo "XScreenSaver:"
    echo "  Restart with: xscreensaver-command -restart"
    echo "  Preview:      xscreensaver-command -demo"
    echo ""
    echo "Enjoy your eye-candy shaders!"
}

# Run main function
main "$@"
