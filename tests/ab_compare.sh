#!/bin/bash
# ab_compare.sh - A/B benchmark two shader trees.
#
#   ab_compare.sh <treeA> <treeB> <shader-substring> [<shader-substring> ...]
#
# Both trees must have the same layout (shaders/, shaders/effects/, ...).
# For each shader substring the best (warm) FPS of each tree is reported
# side by side together with the delta.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/build/shadercandy-bench"

A="$1"; B="$2"; shift 2

FRAMES="${FRAMES:-200}"
REPS="${REPS:-3}"

# Emit "-dir <root>[-subdir] ..." for every directory that actually exists.
dir_args() {
  local root="$1" d
  for d in "" /base /effects /music /audio /neural /system; do
    if [ -d "$root$d" ]; then printf -- '-dir %q ' "$root$d"; fi
  done
}

best_fps() {
  local root="$1" name="$2"
  # shellcheck disable=SC2046
  timeout 900 "$BENCH" $(dir_args "$root") -shader "$name" -frames "$FRAMES" 2>&1 \
    | sed -n 's/.*] [^ ]*\.\.\. \([0-9.]*\) fps.*/\1/p' | sort -g | tail -1
}

printf '%-26s %12s %12s %10s\n' "SHADER" "A_FPS" "B_FPS" "DELTA%"
printf '%s\n' "----------------------------------------------------------"
for name in "$@"; do
  a=""; b=""
  for _ in $(seq "$REPS" 2>/dev/null || echo 1 2 3); do
    [ "$#" -eq 0 ] && break
    v=$(best_fps "$A" "$name"); [ -n "$v" ] && a="$v"
    v=$(best_fps "$B" "$name"); [ -n "$v" ] && b="$v"
  done
  if [ -z "$a" ] || [ -z "$b" ]; then
    printf '%-26s %12s %12s %10s\n' "$name" "${a:--}" "${b:--}" "n/a"
    continue
  fi
  d=$(awk -v a="$a" -v b="$b" 'BEGIN{printf "%+.1f", (b-a)/a*100}')
  printf '%-26s %12s %12s %10s\n' "$name" "$a" "$b" "$d"
done
printf '%s\n' "----------------------------------------------------------"
printf 'A=%s  B=%s  frames=%s reps=%s\n' "$A" "$B" "$FRAMES" "$REPS"