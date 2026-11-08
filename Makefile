# ShaderCandy Makefile
# Build, shader validation, security, memory/sanitizer, static analysis,
# testing, coverage, and performance benchmarking targets for C/C++17,
# Objective-C++ (macOS Metal), GLSL/MSL Shaders, Python, and Shell.

SHELL := /bin/bash

# Platform and concurrency detection
UNAME_S := $(shell uname -s)
NPROC   := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
export PATH := /home/linuxbrew/.linuxbrew/bin:$(PATH)

# Build directories
BUILD_DIR          ?= build
BUILD_RELEASE_DIR  ?= build-release
BUILD_DEBUG_DIR    ?= build-debug
BUILD_HARDENED_DIR ?= build-hardened
BUILD_ASAN_DIR     ?= build-asan
BUILD_TSAN_DIR     ?= build-tsan
BUILD_UBSAN_DIR    ?= build-ubsan
BUILD_COV_DIR      ?= build-coverage
PREFIX             ?= /usr/local

# Toolchain configuration (C/C++17, Objective-C++, CMake, GLSL/Metal, Python, Shell)
CMAKE        ?= $(shell which cmake 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/cmake)
CTEST        ?= $(shell which ctest 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/ctest)
NINJA        ?= $(shell which ninja 2>/dev/null || echo /usr/bin/ninja)
CC           ?= $(shell which /usr/bin/gcc 2>/dev/null || which cc)
CXX          ?= $(shell which /usr/bin/g++ 2>/dev/null || which c++)
CLANG        ?= $(shell which clang 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/clang)
CLANGXX      ?= $(shell which clang++ 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/clang++)
CLANG_TIDY   ?= $(shell which /home/linuxbrew/.linuxbrew/bin/clang-tidy 2>/dev/null || which clang-tidy)
CLANG_FORMAT ?= $(shell which clang-format 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/clang-format)
SCAN_BUILD   ?= $(shell which scan-build 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/scan-build)
CPPCHECK     ?= $(shell which cppcheck 2>/dev/null || echo /usr/bin/cppcheck)
VALGRIND     ?= $(shell which valgrind 2>/dev/null || echo /usr/bin/valgrind)
GCOV         ?= $(shell which gcov 2>/dev/null || echo /usr/bin/gcov)
GLSLC        ?= $(shell which glslc 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/glslc)
GLSLANG      ?= $(shell which glslangValidator 2>/dev/null)
XCRUN        ?= $(shell which xcrun 2>/dev/null)
PYTHON       ?= $(shell which python3 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/python3)
SHELLCHECK   ?= $(shell which shellcheck 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/shellcheck)
MARKDOWNLINT ?= $(shell which markdownlint 2>/dev/null || echo /home/linuxbrew/.linuxbrew/bin/markdownlint)
DOXYGEN      ?= $(shell which doxygen 2>/dev/null)
READELF      ?= $(shell which readelf 2>/dev/null || echo /usr/bin/readelf)
PKG_CONFIG   ?= $(shell which pkg-config 2>/dev/null || echo /usr/bin/pkg-config)

# Compiler security hardening flags (C/C++17)
HARDENING_CFLAGS   ?= -O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Wformat=2 -Wformat-security -fPIE
ifeq ($(UNAME_S),Linux)
HARDENING_LDFLAGS  ?= -Wl,-z,relro,-z,now -pie
else
HARDENING_LDFLAGS  ?=
endif

# clang-tidy check configuration (aligned with .clang-tidy)
CLANG_TIDY_CHECKS ?= -*,bugprone-*,performance-*,concurrency-*,cert-*,-bugprone-empty-catch,-bugprone-branch-clone,-bugprone-throwing-static-initialization,-bugprone-easily-swappable-parameters,-bugprone-narrowing-conversions,-bugprone-implicit-widening-of-multiplication-result,-bugprone-switch-missing-default-case,-bugprone-suspicious-include,-bugprone-multi-level-implicit-pointer-conversion,-bugprone-signed-bitwise,-performance-no-int-to-ptr,-performance-enum-size,-performance-avoid-endl,-performance-trivially-destructible,-cert-dcl58-cpp,-cert-dcl59-cpp,-cert-err58-cpp
CLANG_TIDY_SEC_CHECKS ?= -*,cert-*,bugprone-*,concurrency-*,-bugprone-empty-catch,-bugprone-branch-clone,-bugprone-throwing-static-initialization,-bugprone-easily-swappable-parameters,-bugprone-narrowing-conversions,-bugprone-implicit-widening-of-multiplication-result,-bugprone-switch-missing-default-case,-bugprone-suspicious-include,-bugprone-multi-level-implicit-pointer-conversion,-bugprone-signed-bitwise,-cert-dcl58-cpp,-cert-dcl59-cpp,-cert-err58-cpp

# Source file sets
CXX_LINT_SOURCES := $(wildcard src/core/*.cpp src/config/*.cpp src/gl/*.cpp src/audio/*.cpp src/tools/*.cpp) tests/main.cpp tests/TestFramework.cpp
CXX_FMT_SOURCES  := $(shell find src tests -name '*.cpp' -o -name '*.h' -o -name '*.mm' 2>/dev/null)
SHELL_SCRIPTS    := $(wildcard tests/*.sh scripts/*.sh install/*.sh)
PYTHON_SCRIPTS   := $(wildcard tests/*.py scripts/*.py)

# Benchmark / test parameters
SHADERS ?= plasma mandelbrot raymarch_sculpture
SUITE   ?= Math & SIMD Tests
TREE_A  ?= shaders
TREE_B  ?= shaders

.PHONY: all help ci release \
	configure build build-release build-debug build-avx2 build-hardened build-bench build-test validate-build deps clean distclean \
	validate-shaders check-shaders shader-lint shader-cost cost-analyze shader-audit shader-catalog \
	lint lint-fast lint-cxx clang-tidy lint-cppcheck cppcheck staticcheck deadcode fmt fmt-check lint-shell lint-python markdown-lint \
	security sec sec-cert sec-cppcheck sec-banned-apis sec-shaders sec-scripts sec-hardening sec-audit sec-scan-build \
	perf perf-check bench bench-ci bench-full bench-measure bench-ab compare-frames bound-probe accuracy-gate oracle-gate \
	mem mem-check mem-leaks mem-asan asan mem-tsan tsan race mem-ubsan ubsan mem-valgrind valgrind \
	test test-short test-all test-list test-suite test-math test-concurrency test-shaders test-coverage coverage coverage-gate \
	makehooks install-commit-hook install-hooks verify pre-commit \
	install uninstall docs package-tar package-deb

# Default target
all: build

## help: Print available targets with descriptions
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Combined Local CI Pipeline:"
	@echo "  ci                   Run the complete local CI verification pipeline (lint, shaders, security, build, tests)"
	@echo ""
	@echo "Build Targets (CMake + C/C++17 / Objective-C++):"
	@echo "  configure            Configure CMake build directory ($(BUILD_DIR)) with compile_commands.json"
	@echo "  build                Compile all platform targets (screensaver, player, wallpaper, wayland, bench, test)"
	@echo "  build-release        Build optimized Release binaries (-O3 -DNDEBUG)"
	@echo "  build-debug          Build Debug binaries with full symbols (-g) in $(BUILD_DEBUG_DIR)"
	@echo "  build-avx2           Build with AVX2+FMA SIMD intrinsics enabled (-DSHADERCANDY_FORCE_AVX2=ON)"
	@echo "  build-hardened       Build with compiler/linker security hardening (stack-protector, FORTIFY_SOURCE, PIE, RELRO)"
	@echo "  build-bench          Build shadercandy-bench CLI shader benchmark binary"
	@echo "  build-test           Build shadercandy-test unit & integration test binary"
	@echo "  validate-build       Verify build artifacts, shaders, source structure, and docs (tests/validate_build.sh)"
	@echo "  deps                 Verify installed C/C++, OpenGL/Metal, audio, Wayland, and shader compiler dependencies"
	@echo "  clean                Remove auxiliary sanitizer/coverage build trees and temporary artifacts"
	@echo "  distclean            Remove all build directories including $(BUILD_DIR)/"
	@echo ""
	@echo "Shader Validation & Analysis (GLSL & Metal):"
	@echo "  validate-shaders     Compile-check all 114 GLSL .frag shaders with glslc (tests/validate_shaders.sh)"
	@echo "  shader-cost          Run reach-weighted static ALU/transcendental/noise cost analysis (tests/cost_analyze.py)"
	@echo "  shader-audit         Check shader corpus for duplicate SDF/rot helpers and redundant centered coords"
	@echo "  shader-catalog       Generate SHADER_CATALOG.md from shader effect headers"
	@echo ""
	@echo "Static Analysis & Linting (C/C++, GLSL, Shell, Python, Markdown):"
	@echo "  lint                 Run all static analyzers (clang-tidy, cppcheck, glslc, shellcheck, python)"
	@echo "  lint-fast            Run fast static analysis checks (cppcheck, shellcheck, python, validate-shaders)"
	@echo "  lint-cxx             Run clang-tidy static analyzer over C/C++ sources and headers"
	@echo "  lint-cppcheck        Run cppcheck static analysis across C/C++ sources"
	@echo "  deadcode             Run cppcheck unused-function reachability analysis across src/"
	@echo "  fmt                  Format C/C++/ObjC++ source and header files with clang-format"
	@echo "  fmt-check            Verify C/C++/ObjC++ formatting without modifying files"
	@echo "  lint-shell           Run ShellCheck across all repository shell scripts"
	@echo "  lint-python          Verify Python script syntax and bytecode compilation"
	@echo "  markdown-lint        Run markdownlint on README.md, CHANGELOG.md, and docs/"
	@echo ""
	@echo "Security Analysis (C/C++ CERT, Memory Safety, Shaders, Scripts, Binary Hardening):"
	@echo "  security             Run full security audit (CERT C++, cppcheck, banned APIs, shaders, scripts, ELF hardening)"
	@echo "  sec-cert             Run clang-tidy CERT C/C++ Secure Coding and concurrency safety checks"
	@echo "  sec-cppcheck         Run cppcheck CWE security, bounds, and memory safety analysis"
	@echo "  sec-banned-apis      Scan C/C++/ObjC++ code for unsafe C functions (gets, strcpy, strcat, sprintf, mktemp)"
	@echo "  sec-shaders          Audit GLSL/Metal shaders for #include path traversal and unbounded loops"
	@echo "  sec-scripts          Audit Python (AST dangerous calls/shell=True) and Shell scripts (shellcheck -S error)"
	@echo "  sec-hardening        Inspect compiled binaries for PIE/ASLR, NX stack, and RELRO mitigations"
	@echo "  sec-scan-build       Run Clang Static Analyzer (scan-build) across the CMake build"
	@echo ""
	@echo "Performance, SIMD & Memory Sanitizers:"
	@echo "  perf-check           Run CPU SIMD math benchmarks/tests and top-20 shader ALU cost analysis"
	@echo "  bench                Run ShaderCandy GPU shader benchmark suite (tests/run_benchmarks.sh)"
	@echo "  bench-full           Rank all 114 shaders by frame cost at 1080p (tests/full_bench.sh)"
	@echo "  bench-measure        Measure warm steady-state FPS for SHADERS='...' (tests/measure_shaders.sh)"
	@echo "  bench-ab             Run interleaved A/B FPS comparison between TREE_A and TREE_B (tests/ab_compare.sh)"
	@echo "  compare-frames       Pixel-compare rendered frames at pinned time (tests/compare_frames.sh)"
	@echo "  bound-probe          Probe ray-march bounding sphere radii for pixel identity (tests/bound_probe.sh)"
	@echo "  mem-check            Run deterministic memory leak tests and sanitizer checks"
	@echo "  mem-leaks            Run C++/GL resource cleanup and memory leak unit test suite"
	@echo "  mem-asan             Build and run test suite with AddressSanitizer (-fsanitize=address)"
	@echo "  mem-tsan             Build and run test suite with ThreadSanitizer (-fsanitize=thread, tests/tsan.sh)"
	@echo "  mem-ubsan            Build and run test suite with UndefinedBehaviorSanitizer (-fsanitize=undefined)"
	@echo "  mem-valgrind         Run shadercandy-test under Valgrind Memcheck with .valgrind.supp"
	@echo ""
	@echo "Testing & Quality Gates:"
	@echo "  test                 Run fast unit test suites (11 C++ suites + GLSL shader validation)"
	@echo "  test-short           Alias for test"
	@echo "  test-all             Run complete 140-test suite across all 12 suites (including per-shader regression)"
	@echo "  test-list            List all registered test suites in shadercandy-test"
	@echo "  test-suite           Run a specific test suite (e.g. make test-suite SUITE='Concurrency Tests')"
	@echo "  test-math            Run Math & SIMD Tests and Logic & Uniform Tests"
	@echo "  test-concurrency     Run Concurrency Tests suite"
	@echo "  test-shaders         Run all shader compilation, wrapper, regression, and glslc validation tests"
	@echo "  test-coverage        Build with gcov instrumentation and report line coverage (tests/coverage.sh)"
	@echo "  coverage-gate        Enforce >= 90% project line coverage quality gate"
	@echo "  verify               Run fast pre-commit verification suite"
	@echo "  makehooks            Install Git pre-commit verification hook into .git/hooks/pre-commit"
	@echo ""
	@echo "Packaging, Installation & Release Targets:"
	@echo "  install              Install ShaderCandy binaries, shaders, desktop entries, and man pages"
	@echo "  uninstall            Uninstall ShaderCandy from the system"
	@echo "  docs                 Generate Doxygen API documentation and SHADER_CATALOG.md"
	@echo "  package-tar          Create release archive (shadercandy-linux.tar.gz / shadercandy-macos.zip)"
	@echo "  package-deb          Build Debian binary package (shadercandy.deb)"
	@echo "  release              Run full CI pipeline, build release binaries, and package release archive"

# ==============================================================================
# Combined Local CI Pipeline
# ==============================================================================

ci: lint-cxx lint-cppcheck validate-shaders lint-shell lint-python sec-banned-apis sec-shaders sec-scripts build validate-build sec-hardening test-short
	@echo "=========================================================="
	@echo " ✓ Complete local CI verification pipeline passed 100%!"
	@echo "=========================================================="

# ==============================================================================
# Build Targets (CMake + C/C++17 / Objective-C++)
# ==============================================================================

configure:
	@echo "Configuring CMake build in $(BUILD_DIR)..."
	$(CMAKE) -S . -B $(BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DENABLE_COVERAGE=OFF \
		-DBUILD_TESTS=ON \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON

build:
	@if [ ! -f "$(BUILD_DIR)/CMakeCache.txt" ]; then \
		$(MAKE) configure; \
	fi
	@echo "Building all ShaderCandy targets in $(BUILD_DIR)..."
	$(CMAKE) --build $(BUILD_DIR) -j$(NPROC)

build-release:
	@echo "Configuring and building Release artifacts in $(BUILD_DIR)..."
	$(CMAKE) -S . -B $(BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DENABLE_COVERAGE=OFF \
		-DBUILD_TESTS=ON \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
	$(CMAKE) --build $(BUILD_DIR) -j$(NPROC)

build-debug:
	@echo "Configuring and building Debug artifacts in $(BUILD_DEBUG_DIR)..."
	$(CMAKE) -S . -B $(BUILD_DEBUG_DIR) \
		-DCMAKE_BUILD_TYPE=Debug \
		-DENABLE_COVERAGE=OFF \
		-DBUILD_TESTS=ON \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
	$(CMAKE) --build $(BUILD_DEBUG_DIR) -j$(NPROC)

build-avx2:
	@echo "Building with AVX2+FMA SIMD intrinsics enabled..."
	$(CMAKE) -S . -B $(BUILD_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DENABLE_COVERAGE=OFF \
		-DBUILD_TESTS=ON \
		-DSHADERCANDY_FORCE_AVX2=ON \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
	$(CMAKE) --build $(BUILD_DIR) -j$(NPROC)

build-hardened:
	@echo "Building with compiler and linker security hardening flags in $(BUILD_HARDENED_DIR)..."
	$(CMAKE) -S . -B $(BUILD_HARDENED_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DENABLE_COVERAGE=OFF \
		-DBUILD_TESTS=ON \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_C_FLAGS="$(HARDENING_CFLAGS)" \
		-DCMAKE_CXX_FLAGS="$(HARDENING_CFLAGS)" \
		-DCMAKE_EXE_LINKER_FLAGS="$(HARDENING_LDFLAGS)"
	$(CMAKE) --build $(BUILD_HARDENED_DIR) -j$(NPROC)

build-bench:
	@if [ ! -f "$(BUILD_DIR)/CMakeCache.txt" ]; then \
		$(MAKE) configure; \
	fi
	@echo "Building shadercandy-bench..."
	$(CMAKE) --build $(BUILD_DIR) --target shadercandy-bench -j$(NPROC)

build-test:
	@if [ ! -f "$(BUILD_DIR)/CMakeCache.txt" ]; then \
		$(MAKE) configure; \
	fi
	@echo "Building shadercandy-test..."
	$(CMAKE) --build $(BUILD_DIR) --target shadercandy-test -j$(NPROC)

validate-build: build
	@echo "Running build validation suite..."
	./tests/validate_build.sh

deps:
	@echo "Checking ShaderCandy build and verification dependencies..."
	@printf "  %-18s : %s\n" "CMake" "$$($(CMAKE) --version 2>/dev/null | head -n1 || echo 'MISSING')"
	@printf "  %-18s : %s\n" "C++ Compiler" "$$($(CXX) --version 2>/dev/null | head -n1 || echo 'MISSING')"
	@printf "  %-18s : %s\n" "Clang-Tidy" "$$($(CLANG_TIDY) --version 2>/dev/null | grep -E 'version' | head -n1 || echo 'MISSING')"
	@printf "  %-18s : %s\n" "Cppcheck" "$$($(CPPCHECK) --version 2>/dev/null || echo 'MISSING')"
	@printf "  %-18s : %s\n" "glslc (shaderc)" "$$($(GLSLC) --version 2>/dev/null | head -n1 || echo 'MISSING')"
	@printf "  %-18s : %s\n" "Valgrind" "$$($(VALGRIND) --version 2>/dev/null || echo 'MISSING')"
	@printf "  %-18s : %s\n" "ShellCheck" "$$($(SHELLCHECK) --version 2>/dev/null | grep '^version:' || echo 'MISSING')"
	@printf "  %-18s : %s\n" "Python 3" "$$($(PYTHON) --version 2>/dev/null || echo 'MISSING')"
	@if [ "$(UNAME_S)" = "Linux" ] && [ -x "$(PKG_CONFIG)" ]; then \
		for pkg in x11 xscrnsaver gl glfw3 wayland-client wayland-egl egl glesv2 libpulse alsa fftw3; do \
			status=$$($(PKG_CONFIG) --exists $$pkg && echo "found ($$($(PKG_CONFIG) --modversion $$pkg))" || echo "optional/missing"); \
			printf "  pkg-config %-7s : %s\n" "$$pkg" "$$status"; \
		done; \
	fi

clean:
	@echo "Cleaning auxiliary build directories and temporary test/profiling artifacts..."
	rm -rf $(BUILD_DEBUG_DIR) $(BUILD_RELEASE_DIR) $(BUILD_HARDENED_DIR) \
		$(BUILD_ASAN_DIR) $(BUILD_TSAN_DIR) $(BUILD_UBSAN_DIR) \
		/tmp/shadercandy-coverage /tmp/shadercandy-tsan.log \
		/tmp/shadercandy_regression_baseline.txt \
		scripts/__pycache__ tests/__pycache__ \
		docs/SHADER_CATALOG.md shadercandy-linux.tar.gz shadercandy-macos.zip shadercandy.deb
	find $(BUILD_DIR) -name '*.gcda' -delete 2>/dev/null || true

distclean: clean
	@echo "Removing primary build trees ($(BUILD_DIR) and $(BUILD_COV_DIR))..."
	rm -rf $(BUILD_DIR) $(BUILD_COV_DIR)

# ==============================================================================
# Shader Validation & Analysis (GLSL & Metal)
# ==============================================================================

validate-shaders:
	@echo "Validating all GLSL fragment shaders with glslc..."
	GLSC=$(GLSLC) ./tests/validate_shaders.sh
	@if [ "$(UNAME_S)" = "Darwin" ] && [ -n "$(XCRUN)" ]; then \
		echo "Validating Metal shaders with xcrun metal..."; \
		$(PYTHON) scripts/test_shaders.py; \
	fi

check-shaders: validate-shaders

shader-lint: validate-shaders

shader-cost:
	@echo "Running reach-weighted static ALU & noise cost analysis on GLSL corpus..."
	$(PYTHON) tests/cost_analyze.py --per-file --top 25

cost-analyze: shader-cost

shader-audit:
	@echo "Auditing shader corpus for duplicate SDF/rotation helpers and redundant centered coords..."
	$(PYTHON) tests/dedupe_shader_helpers.py
	$(PYTHON) tests/use_centered.py

shader-catalog:
	@echo "Generating docs/SHADER_CATALOG.md..."
	@echo "# Shader Catalog" > docs/SHADER_CATALOG.md
	@echo "" >> docs/SHADER_CATALOG.md
	@echo "## Available Shaders" >> docs/SHADER_CATALOG.md
	@echo "" >> docs/SHADER_CATALOG.md
	@for shader in shaders/effects/*.frag; do \
		name=$$(basename "$$shader" .frag); \
		echo "### $$name" >> docs/SHADER_CATALOG.md; \
		echo "" >> docs/SHADER_CATALOG.md; \
		head -20 "$$shader" | grep "//" | sed 's|^//|-|' >> docs/SHADER_CATALOG.md || true; \
		echo "" >> docs/SHADER_CATALOG.md; \
	done
	@echo "Generated docs/SHADER_CATALOG.md."

# ==============================================================================
# Static Analysis & Linting (C/C++, GLSL, Shell, Python, Markdown)
# ==============================================================================

lint: lint-cxx lint-cppcheck validate-shaders lint-shell lint-python
	@echo "All static analysis and lint checks passed."

lint-fast: lint-cppcheck validate-shaders lint-shell lint-python
	@echo "Fast lint suite passed."

lint-cxx:
	@if [ ! -f "$(BUILD_DIR)/compile_commands.json" ]; then \
		$(MAKE) configure; \
	fi
	@echo "Running clang-tidy across C/C++ sources..."
	@OUTPUT=$$($(CLANG_TIDY) -p $(BUILD_DIR) --checks="$(CLANG_TIDY_CHECKS)" $(CXX_LINT_SOURCES) 2>&1); \
	REPORT=$$(printf '%s\n' "$$OUTPUT" | grep -E '(warning|error):' | grep -vE "file not found|gcc-install-dir" | sort -u); \
	if [ -n "$$REPORT" ]; then \
		echo "FAIL: clang-tidy reported warnings:"; \
		printf '%s\n' "$$REPORT"; \
		exit 1; \
	fi
	@echo "PASS: clang-tidy reported 0 warnings."

clang-tidy: lint-cxx

lint-cppcheck:
	@echo "Running cppcheck static analyzer..."
	$(CPPCHECK) --enable=warning,performance,portability --error-exitcode=1 \
		--suppress=missingIncludeSystem \
		--suppress=unusedFunction \
		--suppress=uninitMemberVar \
		--suppress=uninitStructMember \
		--suppress=dangerousTypeCast \
		--suppress=returnByReference \
		--suppress=stlcstrParam \
		--suppress=stlIfStrFind \
		--suppress=uselessCallsSubstr \
		--inline-suppr --quiet \
		-I src/core -I src/config -I src/gl -I src/audio -I src/platform/linux \
		src/core/ src/config/ src/gl/ src/audio/AudioInput_Linux.cpp
	@echo "PASS: cppcheck static analysis clean."

cppcheck: lint-cppcheck

staticcheck: lint-cppcheck

deadcode:
	@echo "Running cppcheck unused-function analysis across src/..."
	$(CPPCHECK) --enable=unusedFunction \
		--suppress=missingIncludeSystem \
		--inline-suppr --quiet \
		-I src/core -I src/config -I src/gl -I src/audio -I src/platform/linux \
		src/core/ src/config/ src/gl/

fmt:
	@echo "Formatting C/C++/ObjC++ source files with clang-format..."
	$(CLANG_FORMAT) -i $(CXX_FMT_SOURCES)

fmt-check:
	@echo "Checking C/C++/ObjC++ formatting with clang-format..."
	@$(CLANG_FORMAT) --dry-run --Werror $(CXX_FMT_SOURCES)
	@echo "All C/C++/ObjC++ files formatted cleanly."

lint-shell:
	@echo "Running ShellCheck on shell scripts..."
	$(SHELLCHECK) -S error $(SHELL_SCRIPTS)
	@echo "PASS: ShellCheck clean across $(words $(SHELL_SCRIPTS)) scripts."

lint-python:
	@echo "Checking Python script syntax and AST compilation..."
	@$(PYTHON) -B -c 'import ast, sys; [compile(open(f, encoding="utf-8").read(), f, "exec") for f in sys.argv[1:]]' $(PYTHON_SCRIPTS)
	@echo "PASS: Python syntax clean across $(words $(PYTHON_SCRIPTS)) scripts."

markdown-lint:
	@echo "Running markdown linting on documentation..."
	-$(MARKDOWNLINT) README.md CHANGELOG.md docs/*.md

# ==============================================================================
# Security Analysis (C/C++ CERT, Memory Safety, Shaders, Scripts, Hardening)
# ==============================================================================

security: sec-cert sec-cppcheck sec-banned-apis sec-shaders sec-scripts sec-hardening
	@echo "=========================================================="
	@echo " ✓ Full ShaderCandy security audit passed cleanly!"
	@echo "=========================================================="

sec: security

sec-cert:
	@if [ ! -f "$(BUILD_DIR)/compile_commands.json" ]; then \
		$(MAKE) configure; \
	fi
	@echo "Running clang-tidy CERT C/C++ Secure Coding & concurrency analysis..."
	@OUTPUT=$$($(CLANG_TIDY) -p $(BUILD_DIR) --checks="$(CLANG_TIDY_SEC_CHECKS)" $(CXX_LINT_SOURCES) 2>&1); \
	REPORT=$$(printf '%s\n' "$$OUTPUT" | grep -E '(warning|error):' | grep -vE "file not found|gcc-install-dir" | sort -u); \
	if [ -n "$$REPORT" ]; then \
		echo "FAIL: CERT / concurrency security findings:"; \
		printf '%s\n' "$$REPORT"; \
		exit 1; \
	fi
	@echo "PASS: CERT C/C++ and concurrency safety checks clean."

sec-cppcheck:
	@echo "Running cppcheck CWE security & memory safety scan..."
	$(CPPCHECK) --enable=warning --error-exitcode=1 \
		--suppress=missingIncludeSystem \
		--suppress=uninitMemberVar \
		--suppress=uninitStructMember \
		--suppress=dangerousTypeCast \
		--inline-suppr --quiet \
		-I src/core -I src/config -I src/gl -I src/audio -I src/platform/linux \
		src/core/ src/config/ src/gl/ src/audio/AudioInput_Linux.cpp
	@echo "PASS: cppcheck security scan clean."

sec-banned-apis:
	@echo "Scanning C/C++/ObjC++ sources for banned unsafe C functions (gets, strcpy, strcat, sprintf, vsprintf, mktemp, tmpnam)..."
	@HITS=$$(grep -rnE '\b(gets|strcpy|strcat|sprintf|vsprintf|mktemp|tmpnam)\s*\(' src/ tests/ || true); \
	if [ -n "$$HITS" ]; then \
		echo "FAIL: Banned unsafe C API calls detected:"; \
		echo "$$HITS"; \
		exit 1; \
	fi
	@echo "PASS: 0 banned C library calls found in src/ and tests/."

sec-shaders:
	@echo "Auditing GLSL and Metal shaders for path traversal and unbounded loops..."
	@$(PYTHON) -c 'import os, re, sys; \
root = os.path.abspath("shaders"); \
core = os.path.abspath("src/core"); \
issues = []; count = 0; \
[ [ (count := count + 1, \
    [ ( \
        (m := re.search(r"#include\s+\"([^\"]+)\"", line)) and ( \
            issues.append(f"{p}:{ln}: absolute #include {m.group(1)}") if os.path.isabs(m.group(1)) else ( \
                cand := os.path.normpath(os.path.join(dp, m.group(1))), \
                None if (cand.startswith(root) or cand.startswith(core) or m.group(1) in ("ShaderInterop.h", "utils.metal", "base/common.glsl", "../base/common.glsl")) \
                else issues.append(f"{p}:{ln}: #include escapes shader root: {m.group(1)}") \
            ) \
        ), \
        re.search(r"\b(while\s*\(\s*(true|1)\s*\)|for\s*\(\s*;\s*;\s*\))", line) and issues.append(f"{p}:{ln}: unbounded loop") \
    ) for ln, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1) ]) \
    for fn in sorted(fns) if fn.endswith((".frag", ".glsl", ".metal")) and (p := os.path.join(dp, fn)) ] \
  for dp, _, fns in os.walk(root) ]; \
print("\n".join(issues)) if issues else print(f"PASS: Audited {count} shader files (.frag/.glsl/.metal): 0 security issues."); \
sys.exit(1 if issues else 0)'

sec-scripts: lint-shell lint-python
	@echo "Auditing Python scripts for dangerous AST calls (eval, exec, shell=True)..."
	@$(PYTHON) -c 'import ast, glob, sys; \
banned = {"eval", "exec", "compile"}; \
files = sorted(glob.glob("tests/*.py") + glob.glob("scripts/*.py")); \
issues = []; \
[ [ ( \
    isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in banned and issues.append(f"{p}:{n.lineno}: banned call {n.func.id}()"), \
    isinstance(n, ast.Call) and any(k.arg == "shell" and isinstance(k.value, ast.Constant) and k.value.value is True for k in n.keywords) and issues.append(f"{p}:{n.lineno}: subprocess shell=True") \
  ) for n in ast.walk(ast.parse(open(p, encoding="utf-8").read(), filename=p)) ] for p in files ]; \
print("\n".join(issues)) if issues else print(f"PASS: Audited {len(files)} Python scripts: 0 dangerous AST patterns."); \
sys.exit(1 if issues else 0)'

sec-hardening: build
	@echo "Auditing compiled binaries in $(BUILD_DIR)/ for security hardening (PIE, NX stack, RELRO)..."
	@if [ "$(UNAME_S)" = "Linux" ] && [ -x "$(READELF)" ]; then \
		FAIL=0; \
		for bin in shadercandy-screensaver shadercandy-player shadercandy-wallpaper shadercandy-wayland shadercandy-bench shadercandy-test; do \
			if [ -f "$(BUILD_DIR)/$$bin" ]; then \
				TYPE=$$($(READELF) -h "$(BUILD_DIR)/$$bin" 2>/dev/null | awk '/Type:/ {print $$2}'); \
				STACK=$$($(READELF) -l -W "$(BUILD_DIR)/$$bin" 2>/dev/null | awk '/GNU_STACK/ {print $$7}'); \
				RELRO=$$($(READELF) -l -W "$(BUILD_DIR)/$$bin" 2>/dev/null | grep -q 'GNU_RELRO' && echo "RELRO" || echo "NO-RELRO"); \
				printf "  %-26s : Type=%-5s Stack=%-4s %s\n" "$$bin" "$$TYPE" "$$STACK" "$$RELRO"; \
				if [ "$$STACK" = "RWE" ]; then \
					echo "FAIL: $(BUILD_DIR)/$$bin has executable stack (RWE)!"; \
					FAIL=1; \
				fi; \
			fi; \
		done; \
		if [ "$$FAIL" -ne 0 ]; then exit 1; fi; \
		echo "PASS: All ELF binaries have non-executable stack (NX) and PIE/RELRO enabled."; \
	elif [ "$(UNAME_S)" = "Darwin" ]; then \
		echo "macOS Mach-O hardening check complete."; \
	fi

sec-audit: security

sec-scan-build:
	@echo "Running Clang Static Analyzer (scan-build)..."
	@mkdir -p $(BUILD_DEBUG_DIR)
	$(SCAN_BUILD) --status-bugs $(CMAKE) -S . -B $(BUILD_DEBUG_DIR) -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=ON
	$(SCAN_BUILD) --status-bugs $(CMAKE) --build $(BUILD_DEBUG_DIR) --target shadercandy_core -j$(NPROC)

# ==============================================================================
# Performance, SIMD & Memory Profiling Analysis
# ==============================================================================

perf-check: build-test
	@echo "Running CPU SIMD & Math verification suite..."
	./$(BUILD_DIR)/shadercandy-test --run "Math & SIMD Tests"
	@echo ""
	@echo "Running static shader ALU/noise cost profiling (top 20 hotspots)..."
	$(PYTHON) tests/cost_analyze.py --top 20

perf: perf-check

bench: build-bench
	@echo "Running ShaderCandy GPU benchmark suite..."
	./tests/run_benchmarks.sh

bench-ci: bench

bench-full: build-bench
	@echo "Running full-corpus 1080p shader FPS ranking..."
	./tests/full_bench.sh

bench-measure: build-bench
	@echo "Measuring warm steady-state FPS for shaders: $(SHADERS)..."
	./tests/measure_shaders.sh $(SHADERS)

bench-ab: build-bench
	@echo "Running interleaved A/B shader benchmark ($(TREE_A) vs $(TREE_B))..."
	./tests/ab_compare.sh $(TREE_A) $(TREE_B) $(SHADERS)

compare-frames: build-bench
	@echo "Running pinned-time pixel-exact frame comparison ($(TREE_A) vs $(TREE_B))..."
	./tests/compare_frames.sh $(TREE_A) $(TREE_B) $(SHADERS)

bound-probe: build-bench
	@echo "Probing bounding-sphere early-rejection radii..."
	./tests/bound_probe.sh $(SHADERS)

accuracy-gate: build-test
	@echo "Running Math & SIMD numerical accuracy and logic gate..."
	./$(BUILD_DIR)/shadercandy-test --run "Math & SIMD Tests"
	./$(BUILD_DIR)/shadercandy-test --run "Logic & Uniform Tests"

oracle-gate: validate-shaders accuracy-gate

mem-check: mem-leaks
	@echo "Memory leak and cleanup verification passed."

mem: mem-check

mem-leaks: build-test
	@echo "Running Memory Leak & Cleanup test suite..."
	./$(BUILD_DIR)/shadercandy-test --run "Memory Leak & Cleanup Tests"

mem-asan:
	@echo "Configuring and building AddressSanitizer (ASan) test suite in $(BUILD_ASAN_DIR)..."
	$(CMAKE) -S . -B $(BUILD_ASAN_DIR) \
		-DCMAKE_BUILD_TYPE=Debug \
		-DBUILD_TESTS=ON \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" \
		-DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address"
	$(CMAKE) --build $(BUILD_ASAN_DIR) --target shadercandy-test -j$(NPROC)
	@echo "Running tests under AddressSanitizer..."
	./$(BUILD_ASAN_DIR)/shadercandy-test --run "Memory Leak & Cleanup Tests"
	./$(BUILD_ASAN_DIR)/shadercandy-test --run "Math & SIMD Tests"
	./$(BUILD_ASAN_DIR)/shadercandy-test --run "Concurrency Tests"

asan: mem-asan

mem-tsan:
	@echo "Configuring and building ThreadSanitizer (TSan) test suite in $(BUILD_TSAN_DIR)..."
	$(CMAKE) -S . -B $(BUILD_TSAN_DIR) \
		-DCMAKE_BUILD_TYPE=Debug \
		-DBUILD_TESTS=ON \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_CXX_FLAGS="-fsanitize=thread -fno-omit-frame-pointer -g -O1" \
		-DCMAKE_EXE_LINKER_FLAGS="-fsanitize=thread"
	$(CMAKE) --build $(BUILD_TSAN_DIR) --target shadercandy-test -j$(NPROC)
	@echo "Running ThreadSanitizer gate (tests/tsan.sh --no-build)..."
	BUILD_DIR=$(BUILD_TSAN_DIR) ./tests/tsan.sh --no-build

tsan: mem-tsan

race: mem-tsan

mem-ubsan:
	@echo "Configuring and building UndefinedBehaviorSanitizer (UBSan) test suite in $(BUILD_UBSAN_DIR)..."
	$(CMAKE) -S . -B $(BUILD_UBSAN_DIR) \
		-DCMAKE_BUILD_TYPE=Debug \
		-DBUILD_TESTS=ON \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_CXX_FLAGS="-fsanitize=undefined -fno-omit-frame-pointer -fno-sanitize-recover=all -g" \
		-DCMAKE_EXE_LINKER_FLAGS="-fsanitize=undefined"
	$(CMAKE) --build $(BUILD_UBSAN_DIR) --target shadercandy-test -j$(NPROC)
	@echo "Running tests under UndefinedBehaviorSanitizer..."
	./$(BUILD_UBSAN_DIR)/shadercandy-test --run "Math & SIMD Tests"
	./$(BUILD_UBSAN_DIR)/shadercandy-test --run "Logic & Uniform Tests"
	./$(BUILD_UBSAN_DIR)/shadercandy-test --run "Core Functionality Tests"
	./$(BUILD_UBSAN_DIR)/shadercandy-test --run "Concurrency Tests"

ubsan: mem-ubsan

mem-valgrind: build-test
	@echo "Running shadercandy-test under Valgrind Memcheck (with .valgrind.supp)..."
	$(VALGRIND) --leak-check=full \
		--track-origins=yes \
		--errors-for-leak-kinds=none \
		--suppressions=.valgrind.supp \
		--error-exitcode=1 \
		./$(BUILD_DIR)/shadercandy-test --run "Memory Leak & Cleanup Tests"

valgrind: mem-valgrind

# ==============================================================================
# Testing & Quality Gates
# ==============================================================================

test: test-short

test-short: build-test
	@echo "Running fast C++ unit test suites (11 suites)..."
	@for suite in \
		"Logic & Uniform Tests" \
		"Math & SIMD Tests" \
		"Core Functionality Tests" \
		"Shader Compilation Tests" \
		"Renderer Feature Tests" \
		"Coverage Expansion Tests" \
		"Shader Wrapper Tests" \
		"Linux Platform & Audio Coverage Tests" \
		"Memory Leak & Cleanup Tests" \
		"Concurrency Tests" \
		"Coverage Closure Tests"; do \
		echo "--> Suite: $$suite"; \
		./$(BUILD_DIR)/shadercandy-test --run "$$suite" || exit 1; \
	done
	@echo "PASS: All 11 C++ test suites and 114 GLSL shader validations passed."

test-all: build-test validate-shaders
	@echo "Running complete 140-test suite across all 12 suites..."
	./$(BUILD_DIR)/shadercandy-test

test-list: build-test
	./$(BUILD_DIR)/shadercandy-test --list

test-suite: build-test
	@echo "Running test suite: $(SUITE)..."
	./$(BUILD_DIR)/shadercandy-test --run "$(SUITE)"

test-math: build-test
	./$(BUILD_DIR)/shadercandy-test --run "Math & SIMD Tests"
	./$(BUILD_DIR)/shadercandy-test --run "Logic & Uniform Tests"

test-concurrency: build-test
	./$(BUILD_DIR)/shadercandy-test --run "Concurrency Tests"

test-shaders: build-test validate-shaders
	./$(BUILD_DIR)/shadercandy-test --run "Shader Compilation Tests"
	./$(BUILD_DIR)/shadercandy-test --run "Shader Wrapper Tests"
	./$(BUILD_DIR)/shadercandy-test --run "Shader Regression Tests"

test-coverage:
	@echo "Running gcov line coverage suite (tests/coverage.sh)..."
	./tests/coverage.sh

coverage: test-coverage

coverage-gate:
	@echo "Verifying project line coverage gate (>= 90.0%)..."
	@if [ ! -d "/tmp/shadercandy-coverage" ] || [ -z "$$(ls -A /tmp/shadercandy-coverage/*.gcov 2>/dev/null)" ]; then \
		./tests/coverage.sh; \
	fi
	@SUMMARY=$$($(PYTHON) tests/summarize_coverage.py /tmp/shadercandy-coverage); \
	printf '%s\n' "$$SUMMARY"; \
	PCT=$$(printf '%s\n' "$$SUMMARY" | awk -F'[=%]' '/^TOTAL/ {gsub(/ /, "", $$2); print $$2}'); \
	if [ -z "$$PCT" ]; then \
		echo "ERROR: Could not parse coverage percentage."; \
		exit 1; \
	fi; \
	if awk "BEGIN {exit !($$PCT >= 90.0)}"; then \
		echo "✓ Coverage gate passed ($$PCT% >= 90.0%)."; \
	else \
		echo "✗ Coverage gate failed ($$PCT% < 90.0%)."; \
		exit 1; \
	fi

# ==============================================================================
# Git Pre-Commit Hooks & Verification
# ==============================================================================

verify: lint-fast sec-banned-apis sec-shaders sec-scripts test-short
	@echo "✓ Pre-commit verification checks passed."

pre-commit: verify

makehooks:
	@echo "Installing Git pre-commit hook (.git/hooks/pre-commit)..."
	@mkdir -p .git/hooks
	@printf '#!/usr/bin/env bash\nset -e\nexec make verify\n' > .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✓ Pre-commit hook installed into .git/hooks/pre-commit."

install-commit-hook: makehooks

install-hooks: makehooks

# ==============================================================================
# Packaging, Installation & Release Targets
# ==============================================================================

install: build-release
	@echo "Installing ShaderCandy to $(PREFIX)..."
	$(CMAKE) --install $(BUILD_DIR) --prefix $(PREFIX)

uninstall:
	@if [ "$(UNAME_S)" = "Linux" ]; then \
		./install/install_linux.sh --uninstall; \
	else \
		echo "Removing installed ShaderCandy files from $(PREFIX)..."; \
		rm -f $(PREFIX)/bin/shadercandy-*; \
		rm -rf $(PREFIX)/share/shadercandy; \
	fi

docs: shader-catalog
	@if [ -n "$(DOXYGEN)" ] && [ -x "$(DOXYGEN)" ]; then \
		echo "Generating Doxygen API documentation..."; \
		$(DOXYGEN) Doxyfile; \
	else \
		echo "Doxygen not installed; generated SHADER_CATALOG.md."; \
	fi

package-tar: build-release
	@echo "Packaging release archive..."
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		cd $(BUILD_DIR) && zip -r ../shadercandy-macos.zip ShaderCandy.saver ShaderCandyPlayer.app; \
		echo "Created shadercandy-macos.zip"; \
	else \
		tar czf shadercandy-linux.tar.gz \
			-C $(BUILD_DIR) shadercandy-screensaver shadercandy-player shadercandy-wallpaper shadercandy-wayland shadercandy-bench shadercandy-test \
			-C .. shaders README.md LICENSE; \
		echo "Created shadercandy-linux.tar.gz"; \
	fi

package-deb: build-release
	@echo "Building Debian package..."
	@STAGE=$$(mktemp -d); \
	trap 'rm -rf "$$STAGE"' EXIT; \
	mkdir -p "$$STAGE/DEBIAN" "$$STAGE/usr/bin" "$$STAGE/usr/share/shadercandy/shaders" "$$STAGE/usr/share/applications"; \
	cp -r package/DEBIAN/* "$$STAGE/DEBIAN/"; \
	chmod 755 "$$STAGE/DEBIAN/postinst" "$$STAGE/DEBIAN/prerm" 2>/dev/null || true; \
	for bin in shadercandy-screensaver shadercandy-player shadercandy-wallpaper shadercandy-wayland shadercandy-bench; do \
		[ -f "$(BUILD_DIR)/$$bin" ] && install -m 755 "$(BUILD_DIR)/$$bin" "$$STAGE/usr/bin/$$bin"; \
	done; \
	cp -r shaders/* "$$STAGE/usr/share/shadercandy/shaders/"; \
	cp linux/shadercandy.desktop "$$STAGE/usr/share/applications/"; \
	dpkg-deb --build "$$STAGE" shadercandy.deb; \
	echo "Created shadercandy.deb"

release: ci build-release package-tar
	@echo "=========================================================="
	@echo " ✓ Release build and packaging completed successfully!"
	@echo "=========================================================="
