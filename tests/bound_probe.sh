#!/bin/bash
# bound_probe.sh - determine the smallest safe bounding radius for a fractal
# ray-march by rendering with the early-out enabled at a candidate radius and
# pixel-comparing against the unmodified shader.
#
#   bound_probe.sh <shader> <radius> [...]
#
# Usage: edit the shader under test to gate on `BOUND_RADIUS`, then run this.
# Any radius whose output is pixel-identical to the ungated render is a valid
# conservative bound.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/build/shadercandy-bench"

name="$1"; shift
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT

DIRS=(-dir "$ROOT/shaders" -dir "$ROOT/shaders/base" -dir "$ROOT/shaders/effects" \
      -dir "$ROOT/shaders/music" -dir "$ROOT/shaders/audio" \
      -dir "$ROOT/shaders/neural" -dir "$ROOT/shaders/system")

"$BENCH" "${DIRS[@]}" -shader "$name" -frames 2 -width 640 -height 360 \
  -time 2.5 -screenshot "$t/ref" >/dev/null 2>&1
ref="$t/ref/$name.ppm"
[ -f "$ref" ] || { echo "no reference frame"; exit 1; }

for R in "$@"; do
  sed -i -E "s/^const float BOUND_RADIUS = .*/const float BOUND_RADIUS = $R;/" \
    "$ROOT/shaders/effects/$name.frag"
  "$BENCH" "${DIRS[@]}" -shader "$name" -frames 2 -width 640 -height 360 \
    -time 2.5 -screenshot "$t/r$R" >/dev/null 2>&1
  got="$t/r$R/$name.ppm"
  if [ ! -f "$got" ]; then printf 'R=%-8s MISSING\n' "$R"; continue; fi
  if cmp -s "$ref" "$got"; then verdict="identical"; else
    verdict=$(python3 -c "
def load(p):
    f=open(p,'rb'); f.readline(); l=f.readline()
    while l.startswith(b'#'): l=f.readline()
    f.readline(); return f.read()
a=load('$ref'); b=load('$got')
d=[abs(x-y) for x,y in zip(a,b)]
nz=sum(1 for x in d if x)
print(f'DIFFERS {nz} ch, max {max(d)}')
")
  fi
  fps=$("$BENCH" "${DIRS[@]}" -shader "$name" -frames 30 2>&1 \
        | sed -n 's/.*] [^ ]*\.\.\. \([0-9.]*\) fps.*/\1/p' | sort -g | tail -1)
  printf 'R=%-8s %-24s fps=%s\n' "$R" "$verdict" "$fps"
done