#!/bin/bash
# Debian package builder for ShaderCandy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build-deb"
VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}ShaderCandy Debian Package Builder${NC}"
echo "===================================="
echo ""

# Check for required tools
echo "Checking dependencies..."
if ! command -v dpkg-buildpackage &> /dev/null; then
    echo -e "${RED}Error: dpkg-buildpackage not found. Install dpkg-dev${NC}"
    exit 1
fi

if ! command -v cmake &> /dev/null; then
    echo -e "${RED}Error: cmake not found${NC}"
    exit 1
fi

# Clean and create build directory
echo "Setting up build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy source to build directory (excluding build-deb and .git)
echo "Copying source files..."
rsync -av --exclude='build-deb' --exclude='.git' --exclude='build' "$PROJECT_ROOT/" "$BUILD_DIR/" 2>/dev/null || \
  (find "$PROJECT_ROOT" -maxdepth 1 -not -path "$PROJECT_ROOT" -not -path "$PROJECT_ROOT/build*" -not -path "$PROJECT_ROOT/.git" -exec cp -r {} "$BUILD_DIR/" \;)

# Copy debian directory
echo "Preparing Debian package files..."
mkdir -p "$BUILD_DIR/debian"
cp -r "$PROJECT_ROOT/linux/debian"/* "$BUILD_DIR/debian/"

# Update version in changelog
sed -i "s/1.0.0/$VERSION/g" "$BUILD_DIR/debian/changelog"

# Build the package
echo ""
echo -e "${YELLOW}Building Debian package...${NC}"
cd "$BUILD_DIR"

dpkg-buildpackage -us -uc -b

# Move built packages to parent directory
echo ""
echo "Moving packages to project root..."
mv ../*.deb "$PROJECT_ROOT/" 2>/dev/null || true
mv ../*.changes "$PROJECT_ROOT/" 2>/dev/null || true
mv ../*.buildinfo "$PROJECT_ROOT/" 2>/dev/null || true

# Clean up
rm -rf "$BUILD_DIR"

echo ""
echo -e "${GREEN}Debian package build complete!${NC}"
echo ""
echo "Package location:"
ls -lh "$PROJECT_ROOT"/*.deb 2>/dev/null || echo "No .deb file found"
echo ""
echo "To install:"
echo "  sudo dpkg -i shadercandy_${VERSION}_*.deb"
echo ""
echo "To install dependencies:"
echo "  sudo apt-get install -f"
