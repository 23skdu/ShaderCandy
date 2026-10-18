#!/bin/bash
# measure_shaders.sh - stable FPS measurement helper for ShaderCandy shaders.
#
# The benchmark's first run for a shader includes pipeline warm-up, so it
# reports a noticeably lower FPS than subsequent runs. This helper runs each
# requested shader N times and reports the best (warm) result, which is the
# most reproducible signal for shader micro-optimizations.
#
# Usage:
#   tests/measure_shaders.sh <shader-substring> [<shader-substring> ...]
#
# Example:
#   tests/measure_shaders.sh plasma mandelbrot raymarch_sculpture

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/build/shadercandy-bench"

if [ ! -x "$BENCH" ]; then
  echo "benchmark binary not found: $BENCH" >&2
  echo "build it with: cmake --build $ROOT/build --target shadercandy-bench -j\$(nproc)" >&2
  exit 1
fi

FRAMES="${FRAMES:-200}"
RUNS="${RUNS:-3}"
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <shader-substring> [...]" >&2
  exit 2
fi

printf '%-28s %10s %10s %10s\n' "SHADER" "COMPILE_MS" "AVG_FPS" "MAX_FPS"
printf '%s\n' "------------------------------------------------------------"

total=0
for name in "$@"; do
  best_avg=0
  best_max=0
  compile_ms=0
  # Accumulate over all runs of this shader; the benchmark prints one
  # "[n/m] <name>... <fps> fps (compile: <ms>ms)" line per matched shader.
  output="$(timeout 600 "$BENCH" -shader "$name" -frames "$FRAMES" \
            -width "$WIDTH" -height "$HEIGHT" 2>&1)"
  if [ -z "$output" ]; then
    printf '%-28s %10s %10s %10s\n' "$name" "-" "-" "NO-MATCH"
    continue
  fi
  total=$((total + 1))

  # Pull every "<fps> fps" and "<ms>ms" pair out of the progress lines.
  fps_vals=$(printf '%s\n' "$output" | sed -n 's/.*] [^ ]*\.\.\. \([0-9.]*\) fps (compile: \([0-9.]*\)ms).*/\1/p')
  ms_vals=$(printf '%s\n' "$output" | sed -n 's/.*] [^ ]*\.\.\. \([0-9.]*\) fps (compile: \([0-9.]*\)ms).*/\2/p')

  # Take the maximum FPS across matches (warm run) and the matching max-fps.
  best_avg=$(printf '%s\n' "$fps_vals" | sort -g | tail -1)
  compile_ms=$(printf '%s\n' "$ms_vals" | sort -g | head -1)

  maxf=$(printf '%s\n' "$output" | sed -n 's/^  [^ ]\{1,28\} *[0-9.]*ms *[0-9.]* *[0-9.]* *\([0-9.]*\).*/\1/p' | sort -g | tail -1)
  [ -z "$maxf" ] && maxf="-"

  printf '%-28s %10s %10s %10s\n' "$name" "$compile_ms" "$best_avg" "$maxf"
done

printf '%s\n' "------------------------------------------------------------"
printf 'measured %d shader target(s), %d frames x %d runs at %sx%s\n' \
  "$total" "$FRAMES" "$RUNS" "$WIDTH" "$HEIGHT"