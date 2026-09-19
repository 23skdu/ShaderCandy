#!/bin/bash
# Test loading specific shaders

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/build"

# Create a simple test by trying to load specific shaders via the test executable
# or by examining the compiled shader libraries

echo "Testing shader files for issues..."
echo ""

# Check if julia_set shader has proper structure
echo "=== julia_set.metal ==="
grep -n "fragment_main\|#include" "$SCRIPT_DIR/shaders/effects/julia_set.metal" | head -10

echo ""
echo "=== mandelbrot_set.metal ==="
grep -n "fragment_main\|#include" "$SCRIPT_DIR/shaders/effects/mandelbrot_set.metal" | head -10

echo ""
echo "=== hiphop.metal (working) ==="
grep -n "fragment_main\|#include" "$SCRIPT_DIR/shaders/music/hiphop.metal" | head -10

echo ""
echo "=== jazz.metal (working) ==="
grep -n "fragment_main\|#include" "$SCRIPT_DIR/shaders/music/jazz.metal" | head -10

echo ""
echo "Checking for common issues..."

# Check for functions that might not exist in ShaderUtils
for shader in julia_set mandelbrot_set julia_3d mandelbrot_3d mandelbulb_3d; do
  echo ""
  echo "=== Checking $shader for ShaderUtils function calls ==="
  grep -o "ShaderUtils::[a-zA-Z_]*" "$SCRIPT_DIR/shaders/effects/$shader.metal" 2>/dev/null || echo "No ShaderUtils calls"
done
