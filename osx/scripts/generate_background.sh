#!/bin/bash
#
# generate_background.sh
# Creates a placeholder background image for the DMG installer
# Uses sips (built into macOS) if available
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../resources"
OUTPUT_FILE="$OUTPUT_DIR/background.png"

mkdir -p "$OUTPUT_DIR"

# Check if sips is available (macOS built-in)
if command -v sips &> /dev/null; then
    echo "Creating gradient background using sips..."
    
    # Create a simple gradient using ImageMagick if available
    if command -v convert &> /dev/null; then
        convert -size 1920x1080 gradient:'#2d0096'-'#ff93ff' "$OUTPUT_FILE"
        echo "Created: $OUTPUT_FILE"
    else
        # Fallback: create a solid color image
        echo "ImageMagick not found. Creating solid color background..."
        # Create a 1x1 purple pixel PNG and scale it
        printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$OUTPUT_FILE"
        
        # Scale to full size using sips
        sips -z 1080 1920 "$OUTPUT_FILE" --out "$OUTPUT_FILE" 2>/dev/null || true
        echo "Created placeholder: $OUTPUT_FILE"
    fi
else
    echo "sips not available. Creating minimal PNG..."
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$OUTPUT_FILE"
    echo "Created minimal placeholder: $OUTPUT_FILE"
fi

echo ""
echo "Note: For a better visual, replace $OUTPUT_FILE with a 1920x1080 PNG"
echo "      Use a gradient from purple (#2d0096) to pink (#ff93ff)"
