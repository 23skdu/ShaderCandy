#!/bin/bash
# ShaderCandy Screenshot Capture Script
# Run this from the ShaderCandy build directory
# Usage: ./capture_screenshots.sh

set -e

APP_PATH="./ShaderCandyPlayer.app"
SHADER_LIST=(
    "vaporwave"
    "jazz"
    "classical"
    "heavymetal"
    "hiphop"
    "reggae"
    "8bit"
    "electronic"
    "punk"
    "soul"
)

OUTPUT_DIR="../thumbnails"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Capturing screenshots for ${#SHADER_LIST[@]} music shaders..."

for SHADER in "${SHADER_LIST[@]}"; do
    echo "Capturing $SHADER..."
    
    # Launch app with specific shader in background
    "$APP_PATH/Contents/MacOS/ShaderCandyPlayer" --shader "$SHADER" &
    APP_PID=$!
    
    # Wait for app to start and render
    sleep 3
    
    # Capture screenshot
    screencapture -x "$OUTPUT_DIR/${SHADER}.png" 2>/dev/null || true
    
    # Kill the app
    kill $APP_PID 2>/dev/null || true
    
    # Wait a moment for cleanup
    sleep 1
    
    if [ -f "$OUTPUT_DIR/${SHADER}.png" ]; then
        echo "  ✓ Saved $OUTPUT_DIR/${SHADER}.png"
    else
        echo "  ✗ Failed to capture $SHADER"
    fi
done

echo ""
echo "Screenshot capture complete!"
echo "Thumbnails saved to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
