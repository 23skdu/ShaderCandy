#!/usr/bin/env bash
# Static analysis gate for ShaderCandy.
#
# Runs clang-tidy over the production and test sources using the build tree's
# compile_commands.json, so every check sees the real include paths and
# preprocessor defines.
#
# Usage:
#   tests/lint.sh                    # lint src/ + tests/ + tools/
#   tests/lint.sh <file> [<file>...] # lint specific files
#
# Requires a configured build tree with compilation database:
#   cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
#
# Exit codes:
#   0  no warnings
#   1  warnings found
#   2  tooling or configuration missing

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

BUILD_DIR="${BUILD_DIR:-build}"
DB="${BUILD_DIR}/compile_commands.json"

if ! command -v clang-tidy >/dev/null 2>&1; then
  echo "ERROR: clang-tidy not found on PATH" >&2
  exit 2
fi

if [[ ! -f "$DB" ]]; then
  echo "ERROR: ${DB} not found." >&2
  echo "       cmake -S . -B ${BUILD_DIR} -DCMAKE_EXPORT_COMPILE_COMMANDS=ON" >&2
  exit 2
fi

if ! clang-tidy --verify-config >/dev/null 2>&1; then
  echo "ERROR: .clang-tidy contains unrecognised options:" >&2
  clang-tidy --verify-config >&2
  exit 2
fi

if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  mapfile -t TARGETS < <(
    find src tests tools -name '*.cpp' -o -name '*.h' 2>/dev/null | sort
  )
fi

echo "clang-tidy: checking ${#TARGETS[@]} file(s) using ${DB}"
echo

# clang-tidy exits non-zero whenever it emits any diagnostic, including the
# header-lookup noise below, so collect the output and decide on the content.

# This Homebrew clang cannot see the Homebrew-installed libstdc++ headers, so
# every TU reports "'<x>' file not found" for standard library includes. Those
# are a toolchain packaging artifact, not defects in the source, and are
# filtered out before deciding the result.
OUTPUT=$(clang-tidy -p "$BUILD_DIR" "${TARGETS[@]}" 2>&1)

REPORT=$(printf '%s\n' "$OUTPUT" \
  | grep -E '(warning|error):' \
  | grep -vE "file not found|gcc-install-dir" \
  | sed "s|$(pwd)/||" \
  | sort -u)

if [[ -z "$REPORT" ]]; then
  echo "PASS: no clang-tidy warnings."
  exit 0
fi

echo "FAIL: clang-tidy reported the following:"
echo
printf '%s\n' "$REPORT"
echo
echo "Count: $(printf '%s\n' "$REPORT" | wc -l)"
exit 1