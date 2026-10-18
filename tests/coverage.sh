#!/usr/bin/env bash
# Measure and report line coverage for ShaderCandy project sources.
#
# Configures an instrumented build, runs the test suite through every CLI
# entry point (so the argument-parsing branches are covered too), then
# summarises gcov output.
#
# Usage:
#   tests/coverage.sh              # configure, build, run, report
#   tests/coverage.sh --no-build   # reuse an existing instrumented build
#
# Environment:
#   BUILD_DIR   build tree to use (default: build-coverage)
#   OUT_DIR     where .gcov files land (default: /tmp/shadercandy-coverage)
#
# Exits 0 regardless of the coverage percentage; the number is reported for
# review, and the ceiling is documented in docs/testing.md.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

BUILD_DIR="${BUILD_DIR:-build-coverage}"
OUT_DIR="${OUT_DIR:-/tmp/shadercandy-coverage}"
DO_BUILD=1
[[ "${1:-}" == "--no-build" ]] && DO_BUILD=0

if [[ ! -x "${BUILD_DIR}/shadercandy-test" ]]; then
  DO_BUILD=1
fi

if [[ $DO_BUILD -eq 1 ]]; then
  echo "== Configuring instrumented build in ${BUILD_DIR} =="
  cmake -S . -B "$BUILD_DIR" \
    -DENABLE_COVERAGE=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DBUILD_TESTS=ON >/dev/null || exit 2

  echo "== Building =="
  cmake --build "$BUILD_DIR" --target shadercandy-test -j"$(nproc)" \
    2>&1 | grep -E '\berror\b' && exit 2
  echo "   ok"
fi

BIN="${BUILD_DIR}/shadercandy-test"
[[ -x "$BIN" ]] || { echo "ERROR: ${BIN} not found" >&2; exit 2; }

echo "== Clearing previous profile data =="
find "$BUILD_DIR" -name '*.gcda' -delete 2>/dev/null
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Every invocation the binary supports. Each is a distinct entry path through
# main() and TestFramework, and coverage only sees what actually runs.
echo "== Running test suite across all entry points =="

run() {
  local label="$1"; shift
  printf '   %-34s' "$label"
  if timeout 900 "$BIN" "$@" >/dev/null 2>&1; then
    echo "ok"
  else
    # --run on a missing suite, and unknown-option, are expected to exit 1.
    local rc=$?
    if [[ "$label" == "unknown option"* || "$label" == "missing suite"* ]]; then
      echo "ok (exit $rc, expected)"
    else
      echo "FAILED (exit $rc)"
      return 1
    fi
  fi
}

STATUS=0
run "all suites"                 || STATUS=1
run "--list"                   --list            || STATUS=1
run "--help"                   --help            || STATUS=1
run "unknown option"           --frobnicate      || STATUS=1
run "missing suite"            --run "No Such Suite" || STATUS=1

# Run each registered suite individually via --run, so every suite's tests are
# attributed even if runAll() short-circuits somewhere.
while IFS= read -r suite; do
  [[ -z "$suite" ]] && continue
  run "--run $suite" --run "$suite" || STATUS=1
done < <("$BIN" --list 2>/dev/null | sed -n 's/^  [0-9]\+\. //p')

[[ $STATUS -eq 0 ]] || { echo "ERROR: some invocations failed" >&2; exit 2; }

echo "== Generating gcov reports =="
# gcov writes .gcov into the current directory but resolves -o and the .gcda
# path against it, so both must be absolute.
BUILD_ABS="$(cd "$BUILD_DIR" && pwd)"
mkdir -p "$OUT_DIR"
OUT_ABS="$(cd "$OUT_DIR" && pwd)"
find "$BUILD_ABS" -name '*.gcda' -print0 | while IFS= read -r -d '' gcda; do
  ( cd "$OUT_ABS" && gcov -b -o "$(dirname "$gcda")" "$gcda" >/dev/null 2>&1 )
done

echo
python3 tests/summarize_coverage.py "$OUT_DIR"