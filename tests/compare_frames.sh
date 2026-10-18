#!/bin/bash
# compare_frames.sh - pixel-compare rendered output of two shader trees.
#
#   compare_frames.sh <treeA> <treeB> <shader> [<shader> ...]
#
# Renders each shader from both trees and compares the PPM dumps byte for byte
# (then reports the max per-channel delta, which catches subtle drift that a
# byte compare would also catch, but states the magnitude).

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/build/shadercandy-bench"

A="$1"; B="$2"; shift 2
# Heavy shaders need enough frames to clear shader compilation inside the
# 600s per-run timeout; 1 is enough once the program is built, but Mesa
# compiles lazily so give the renderer a couple of frames.
FRAMES="${FRAMES:-3}"
CAPTURE_WIDTH="${CAPTURE_WIDTH:-960}"
CAPTURE_HEIGHT="${CAPTURE_HEIGHT:-540}"
JOBS="${JOBS:-4}"

dir_args() {
  local root="$1" d
  for d in "" /base /effects /music /audio /neural /system; do
    [ -d "$root$d" ] && printf -- '-dir %q ' "$root$d"
  done
}

tmpA="$(mktemp -d)"; tmpB="$(mktemp -d)"
trap 'rm -rf "$tmpA" "$tmpB"' EXIT

# The benchmark only screenshots the last -dir processed in one run, so run
# each shader separately against both trees.
render_one() {
  local tree="$1" outdir="$2" name="$3"
  mkdir -p "$outdir"
  local d
  # shellcheck disable=SC2046
  timeout 900 "$BENCH" $(dir_args "$tree") -shader "$name" -frames "$FRAMES" \
    -width "$CAPTURE_WIDTH" -height "$CAPTURE_HEIGHT" \
    -time "${FIXED_TIME:-2.5}" -screenshot "$outdir" >/dev/null 2>&1
}

for s in "$@"; do
  render_one "$A" "$tmpA/$s" "$s"
  render_one "$B" "$tmpB/$s" "$s"
done

printf '%-30s %12s\n' "SHADER" "MAX_DELTA"
printf '%s\n' "--------------------------------------------"
for s in "$@"; do
  a=$(find "$tmpA/$s" -name "$s.ppm" 2>/dev/null | head -1)
  b=$(find "$tmpB/$s" -name "$s.ppm" 2>/dev/null | head -1)
  if [ -z "$a" ] || [ -z "$b" ]; then
    printf '%-30s %12s\n' "$s" "MISSING"
    continue
  fi
  d=$(cmp -s "$a" "$b" && echo "identical" || \
      python3 -c "
import sys
def load(p):
    with open(p,'rb') as f:
        assert f.readline().strip()==b'P6'
        line=f.readline()
        while line.startswith(b'#'): line=f.readline()
        w,h=map(int,line.split()); f.readline()
        return f.read(),w,h
da,_,_=load('$a'); db,_,_=load('$b')
print(max((abs(x-y) for x,y in zip(da,db)), default=0))
")
  printf '%-30s %12s\n' "$s" "$d"
done
printf '%s\n' "--------------------------------------------"