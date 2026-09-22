#!/bin/bash
# Run ShaderCandy performance benchmarks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=================================="
echo "ShaderCandy Performance Benchmarks"
echo "=================================="
echo ""

# Check if benchmark binary exists
BENCHMARK_BIN="$PROJECT_ROOT/build/shadercandy-bench"
if [ ! -f "$BENCHMARK_BIN" ]; then
    echo "Benchmark binary not found at: $BENCHMARK_BIN"
    echo "Building benchmarks..."
    
    cd "$PROJECT_ROOT"
    mkdir -p build
    cd build
    
    if [ ! -f "Makefile" ] && [ ! -f "build.ninja" ]; then
        cmake .. -DBUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release
    fi
    
    cmake --build . --target shadercandy-bench -j$(nproc)
    
    BENCHMARK_BIN="$PROJECT_ROOT/build/shadercandy-bench"
    
    if [ ! -f "$BENCHMARK_BIN" ]; then
        echo "Error: Failed to build benchmark binary"
        exit 1
    fi
fi

echo "Running benchmarks..."
echo ""

# Pass all arguments through to shadercandy-bench, or run with default shader dir
if [ $# -eq 0 ]; then
    "$BENCHMARK_BIN" -dir "$PROJECT_ROOT/shaders" -frames 60
else
    "$BENCHMARK_BIN" "$@"
fi

echo ""
echo "Benchmark run complete!"