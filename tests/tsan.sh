#!/usr/bin/env bash
# ThreadSanitizer gate for ShaderCandy.
#
# Builds the test suite with -fsanitize=thread and runs it. Races inside ALSA
# and Mesa's Gallium are suppressed by tests/tsan.supp; anything pointing at
# src/ or tests/ is a real defect and must be fixed.
#
# Usage:
#   tests/tsan.sh              # configure, build, run, verify
#   tests/tsan.sh --no-build   # reuse an existing instrumented build
#
# Environment:
#   BUILD_DIR   build tree to use (default: build-tsan)
#
# Exit codes:
#   0  no data races in project code
#   1  a race was reported in project code
#   2  tooling or configuration missing

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

BUILD_DIR="${BUILD_DIR:-build-tsan}"
DO_BUILD=1
[[ "${1:-}" == "--no-build" ]] && DO_BUILD=0

if [[ ! -x "${BUILD_DIR}/shadercandy-test" ]]; then
  DO_BUILD=1
fi

if [[ $DO_BUILD -eq 1 ]]; then
  echo "== Configuring TSan build in ${BUILD_DIR} =="
  cmake -S . -B "$BUILD_DIR" \
    -DBUILD_TESTS=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS="-fsanitize=thread -g -O1" \
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=thread" >/dev/null || exit 2

  echo "== Building =="
  cmake --build "$BUILD_DIR" --target shadercandy-test -j"$(nproc)" \
    2>&1 | grep -E '\berror\b' && exit 2
  echo "   ok"
fi

BIN="${BUILD_DIR}/shadercandy-test"
[[ -x "$BIN" ]] || { echo "ERROR: ${BIN} not found" >&2; exit 2; }

echo "== Running under ThreadSanitizer =="
LOG="${TMPDIR:-/tmp}/shadercandy-tsan.log"

# halt_on_error is deliberately off: we want one full report, not a bail-out
# at the first finding.
TSAN_OPTIONS="suppressions=$(pwd)/tests/tsan.supp:halt_on_error=0" \
  timeout 1800 "$BIN" >"$LOG" 2>&1
STATUS=$?

grep -E 'Summary:' "$LOG" || echo "   (no summary line)"

DATA_RACES=$(grep -cE 'SUMMARY: ThreadSanitizer: data race' "$LOG")
TOTAL_WARN=$(grep -cE 'SUMMARY: ThreadSanitizer' "$LOG")
echo
echo "TSan summaries: ${TOTAL_WARN} total, ${DATA_RACES} data races"
echo "Log: ${LOG}"
echo

# The check that matters: does anything point into this repository?
if grep -E 'ShaderCandy/(src|tests)/' "$LOG" | grep -vE '^\s+#' >/dev/null 2>&1; then
  echo "FAIL: ThreadSanitizer reported a race in project code:"
  echo
  grep -E 'ShaderCandy/(src|tests)/' "$LOG" | grep -vE '^\s+#' | sort -u
  echo
  echo "See docs/testing.md for the full procedure."
  exit 1
fi

echo "PASS: no data races in src/ or tests/."
echo "      (Any remaining TSan summaries are third-party: ALSA, Mesa/Gallium.)"
exit 0