#!/bin/bash
# full_bench.sh - rank every shader by frame cost across the whole corpus.
#
#   full_bench.sh [output.json]
#
# The interesting number is FPS: at a fixed 1920x1080 it is inversely
# proportional to per-frame cost, so the slowest shaders are where optimisation
# effort pays. Writes the benchmark's own JSON report and prints a sorted
# table.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/build/shadercandy-bench"
OUT="${1:-/tmp/opencode/full_bench.json}"

DIRS=(-dir "$ROOT/shaders" -dir "$ROOT/shaders/base" -dir "$ROOT/shaders/effects" \
      -dir "$ROOT/shaders/music" -dir "$ROOT/shaders/audio" \
      -dir "$ROOT/shaders/neural" -dir "$ROOT/shaders/system")

timeout 3000 "$BENCH" "${DIRS[@]}" -frames "${FRAMES:-20}" \
  -width "${WIDTH:-1920}" -height "${HEIGHT:-1080}" -json "$OUT" >/dev/null 2>&1

python3 - "$OUT" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
rows = []
for entry in data["shaders"]:
    for name, v in entry.items():
        if not v.get("compiled"):
            rows.append((0.0, name, v.get("path","")))
            continue
        rows.append((v.get("avgFps", 0.0), name, v.get("path","")))
rows.sort()
print(f"{'FPS':>10}  {'SHADER':<28} PATH")
print("-" * 78)
for fps, name, path in rows:
    print(f"{fps:>10.1f}  {name:<28} {path}")
n = len(rows)
print("-" * 78)
print(f"{n} shaders. Slowest 20 are the optimisation targets;")
print(f"median FPS {rows[n//2][0]:.1f}")
PY