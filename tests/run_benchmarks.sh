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
BENCHMARK_BIN="$PROJECT_ROOT/build/shadercandy-benchmark"
if [ ! -f "$BENCHMARK_BIN" ]; then
    echo "Benchmark binary not found at: $BENCHMARK_BIN"
    echo "Building benchmarks..."
    
    cd "$PROJECT_ROOT"
    mkdir -p build
    cd build
    
    if [ ! -f "Makefile" ] && [ ! -f "build.ninja" ]; then
        cmake .. -DBUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release
    fi
    
    make -j$(nproc) shadercandy-benchmark
    
    BENCHMARK_BIN="$PROJECT_ROOT/build/shadercandy-benchmark"
    
    if [ ! -f "$BENCHMARK_BIN" ]; then
        echo "Error: Failed to build benchmark binary"
        exit 1
    fi
fi

echo "Running benchmarks..."
echo ""

# Parse arguments
RUN_ALL=true
RUN_NAME=""
VERBOSE=false
THROUGHPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --run)
            RUN_NAME="$2"
            RUN_ALL=false
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --throughput)
            THROUGHPUT=true
            shift
            ;;
        --list)
            "$BENCHMARK_BIN" --list
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --list               List all available benchmarks"
            echo "  --run <name>         Run specific benchmark suite"
            echo "  --verbose            Show detailed results"
            echo "  --throughput         Show throughput metrics"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run benchmarks
if [ "$RUN_ALL" = true ]; then
    "$BENCHMARK_BIN" --all
else
    "$BENCHMARK_BIN" --run "$RUN_NAME"
fi

if [ "$THROUGHPUT" = true ]; then
    echo ""
    echo "Throughput Metrics:"
    echo "-------------------"
    "$BENCHMARK_BIN" --run "$RUN_NAME" --throughput 2>/dev/null || true
fi

echo ""
echo "Benchmark run complete!"